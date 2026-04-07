import Foundation
import Combine

/// Manages MTP device communication.
final class KalamMTPManager: ObservableObject {
    
    // MARK: – Published State
    @Published var connectionState: ConnectionState = .disconnected
    @Published var files: [MTPFile] = []
    @Published var navigationStack: [String] = []
    @Published var selectedStorage: MTPStorage? = nil
    @Published var isLoading: Bool = false
    @Published var transferProgress: Double? = nil
    @Published var transferStats: TransferStatistics? = nil
    @Published var errorMessage: String? = nil
    @Published private(set) var isTransferActive: Bool = false
    
    var currentPath: String { navigationStack.last ?? "/" }
    var canGoBack: Bool { navigationStack.count > 1 }
    
    var sortedFiles: [MTPFile] {
        files.sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory && !$1.isDirectory }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
    
    // MARK: – Kalam routing (C callbacks cannot capture Swift context)
    private enum Operation {
        case none
        case initializing
        case fetchingStorages
        case walking
        case deleting
        case makingDirectory
        case uploading
        case downloading
        case disposing
    }

    private enum TransferDirection {
        case upload
        case download

        var operation: Operation {
            switch self {
            case .upload: return .uploading
            case .download: return .downloading
            }
        }

        var titleText: String {
            switch self {
            case .upload: return "Uploading…"
            case .download: return "Downloading…"
            }
        }

        var preparingText: String {
            switch self {
            case .upload: return "Preparing upload…"
            case .download: return "Preparing download…"
            }
        }
    }

    private struct TransferRequest {
        let id = UUID()
        let direction: TransferDirection
        let storageId: UInt32
        let sources: [String]
        let destination: String
        let sourceURLsForSecurityScope: [URL]
        let destinationURLForSecurityScope: URL?
        let shouldReloadCurrentPathAfterCompletion: Bool
        let completion: ((Error?) -> Void)?
    }

    private struct ActiveTransferSession {
        let request: TransferRequest
        var preparedPaths: Set<String> = []
        var preparedTotalBytes: Int64 = 0
        var totalFiles: Int64?
        var filesSent: Int64?
        var currentFileName: String?
    }

    private var operation: Operation = .none
    private var transferCompletion: ((Error?) -> Void)?
    private var scopedSourceURLs: [URL] = []
    private var scopedDestinationURL: URL?
    private var pendingTransferRequests: [TransferRequest] = []
    private var activeTransferSession: ActiveTransferSession?
    private var cachedDeviceInfo: (name: String, manufacturer: String)? = nil
    
    // MARK: – Promise Downloads (for multi-select drag-drop)
    private let promiseQueueLock = DispatchQueue(label: "com.openmtp.promise-queue", attributes: [])
    private var promiseDownloadBatch: [(file: MTPFile, destination: URL, completion: (Error?) -> Void)] = []
    private var promiseBatchTimer: Timer?
    private var isProcessingPromiseBatch: Bool = false
    
    // MARK: – USB Hotplug & Retry Logic
    private var usbMonitor: USBMonitor?
    private var hotplugRetryCount: Int = 0
    private var retryTimer: Timer?
    private var shouldIgnoreUSBEvents: Bool = false
    
    
    private enum CallbackRouter {
        static weak var manager: KalamMTPManager?
        
        // These callbacks do not capture any local context.
        static let done: KalamOnCbResult = { jsonPtr in
            CallbackRouter.manager?.handleDone(jsonPtr: jsonPtr)
        }
        
        static let preprocess: KalamOnCbResult = { jsonPtr in
            CallbackRouter.manager?.handlePreprocess(jsonPtr: jsonPtr)
        }
        
        static let progress: KalamOnCbResult = { jsonPtr in
            CallbackRouter.manager?.handleProgress(jsonPtr: jsonPtr)
        }
    }
    
    init() {
        CallbackRouter.manager = self
        
        // Initialize and start USB monitor
        self.usbMonitor = USBMonitor { [weak self] attached in
            self?.handleUSBEvent(attached: attached)
        }
        self.usbMonitor?.startMonitoring()
    }
    
    deinit {
        // Clean up USB monitor and retry timer
        retryTimer?.invalidate()
        retryTimer = nil
        usbMonitor?.stopMonitoring()
        usbMonitor = nil
    }
    
    // MARK: – Callback handlers
    private func handlePreprocess(jsonPtr: UnsafeMutablePointer<CChar>?) {
        // Currently unused by the Swift UI.
        _ = jsonPtr
    }
    
    private func handleProgress(jsonPtr: UnsafeMutablePointer<CChar>?) {
        guard let jsonPtr else { return }
        guard operation == .downloading || operation == .uploading else { return }
        
        let jsonString = String(cString: jsonPtr)
        let (errorString, dataAny) = parseEnvelope(jsonString)
        if let errorString {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if ErrorStringLocalizer.isDeviceDisconnectedError(errorString) {
                    self.handleDeviceDisconnected()
                } else {
                    self.transferProgress = nil
                    self.transferStats = nil
                    let localizedError = ErrorStringLocalizer.localize(errorString)
                    self.connectionState = .error(localizedError)
                    self.errorMessage = localizedError
                }
            }
            operation = .none
            return
        }
        guard let dataAny else { return }
        guard let progressData = decodeFullTransferProgress(from: dataAny) else { return }
        let stats = TransferStatistics(progressData: progressData)
        
        DispatchQueue.main.async { [weak self] in
            self?.transferStats = stats
            self?.transferProgress = stats.progressPercentage
        }
    }
    
    private func handleDone(jsonPtr: UnsafeMutablePointer<CChar>?) {
        guard let jsonPtr else { return }
        
        let jsonString = String(cString: jsonPtr)
        
        switch operation {
        case .initializing:
            if let errorString = parseEnvelopeErrorOnly(jsonString) {
                DispatchQueue.main.async {
                    if ErrorStringLocalizer.isDeviceDisconnectedError(errorString) {
                        self.handleDeviceDisconnected()
                    } else {
                        let localizedError = ErrorStringLocalizer.localize(errorString)
                        self.connectionState = .error(localizedError)
                        self.errorMessage = localizedError
                    }
                }
                operation = .none
                return
            }
            
            // Extract device info from the Initialize response
            if let dataAny = parseEnvelopeData(jsonString),
               let deviceInfo = parseDeviceInfo(dataAny) {
                self.cachedDeviceInfo = deviceInfo
            }
            
            operation = .fetchingStorages
            KalamFetchStorages(CallbackRouter.done)
            
        case .fetchingStorages:
            if let errorString = parseEnvelopeErrorOnly(jsonString) {
                DispatchQueue.main.async {
                    let localizedError = ErrorStringLocalizer.localize(errorString)
                    self.connectionState = .error(localizedError)
                    self.errorMessage = localizedError
                }
                operation = .none
                return
            }
            
            guard let dataAny = parseEnvelopeData(jsonString) else {
                DispatchQueue.main.async {
                    let localizedError = String(localized: "Invalid storages payload")
                    self.connectionState = .error(localizedError)
                }
                operation = .none
                return
            }
            
            let storages = parseStorages(dataAny)
            guard let first = storages.first else {
                DispatchQueue.main.async {
                    let localizedError = String(localized: "No storages found")
                    self.connectionState = .error(localizedError)
                    self.errorMessage = localizedError
                }
                operation = .none
                return
            }
            
            // Use cached device info from initialization, or fallback to defaults
            let deviceName = self.cachedDeviceInfo?.name ?? "MTP Device"
            let deviceManufacturer = self.cachedDeviceInfo?.manufacturer ?? ""
            
            let detectedUSB: USBMonitor.USBDetectionResult = self.usbMonitor?.detectCurrentUSBProtocol(
                productHint: deviceName,
                manufacturerHint: deviceManufacturer
            )
                ?? (protocolName: "Unknown", speedMbps: 0, maxSpeedBytesPerSecond: 42_000_000)
            let usbProtocol = self.mapUSBProtocol(from: detectedUSB.protocolName)
            
            let device = MTPDevice(
                id: "device-1",
                name: deviceName,
                manufacturer: deviceManufacturer,
                storages: storages,
                usbProtocol: usbProtocol,
                usbSpeedMbps: detectedUSB.speedMbps,
                maxSpeedBytesPerSecond: detectedUSB.maxSpeedBytesPerSecond
            )
            DispatchQueue.main.async {
                self.connectionState = .connected(device)
                self.selectedStorage = first
                self.navigationStack = ["/"]
                self.loadFiles(at: "/")
            }
            operation = .none // will be overwritten by loadFiles(_:).
            
        case .walking:
            if let errorString = parseEnvelopeErrorOnly(jsonString) {
                DispatchQueue.main.async {
                    if ErrorStringLocalizer.isDeviceDisconnectedError(errorString) {
                        self.handleDeviceDisconnected()
                    } else {
                        self.isLoading = false
                        let localizedError = ErrorStringLocalizer.localize(errorString)
                        self.connectionState = .error(localizedError)
                        self.errorMessage = localizedError
                    }
                }
                operation = .none
                return
            }
            
            guard let filesAny = parseEnvelopeData(jsonString) else {
                DispatchQueue.main.async { self.isLoading = false }
                operation = .none
                return
            }
            
            let filesData = dataFromAny(filesAny)
            if filesData.isEmpty {
                // e.g. empty directory listing: kalam typically returns `data: []`.
                DispatchQueue.main.async {
                    self.files = []
                    self.isLoading = false
                }
                operation = .none
                return
            }
            guard let decoded = try? JSONDecoder().decode([KalamWalkFileInfo].self, from: filesData) else {
                DispatchQueue.main.async { self.isLoading = false }
                operation = .none
                return
            }
            
            let mappedFiles: [MTPFile] = decoded.map { fi in
                MTPFile(
                    id: String(fi.objectId),
                    name: fi.name,
                    size: fi.size,
                    dateModified: self.parseKalamDate(fi.dateAdded) ?? Date(),
                    isDirectory: fi.isFolder,
                    path: fi.path,
                    extension_: fi.extension_
                )
            }
            
            DispatchQueue.main.async {
                self.files = mappedFiles
                self.isLoading = false
            }
            operation = .none
            
        case .deleting, .makingDirectory:
            if let errorString = parseEnvelopeErrorOnly(jsonString) {
                DispatchQueue.main.async {
                    if ErrorStringLocalizer.isDeviceDisconnectedError(errorString) {
                        self.handleDeviceDisconnected()
                    } else {
                        let localizedError = ErrorStringLocalizer.localize(errorString)
                        self.connectionState = .error(localizedError)
                        self.errorMessage = localizedError
                    }
                }
                operation = .none
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.loadFiles(at: self.currentPath)
            }
            operation = .none
            
        case .downloading, .uploading:
            // Data is a bool for done.
            if let errorString = parseEnvelopeErrorOnly(jsonString) {
                self.finishTransferCompletion(errorString: errorString)
                DispatchQueue.main.async {
                    if ErrorStringLocalizer.isDeviceDisconnectedError(errorString) {
                        self.handleDeviceDisconnected()
                    } else {
                        self.transferProgress = nil
                        self.transferStats = nil
                        let localizedError = ErrorStringLocalizer.localize(errorString)
                        self.connectionState = .error(localizedError)
                        self.errorMessage = localizedError
                    }
                }
                operation = .none
                return
            }
            
            self.finishTransferCompletion(errorString: nil)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.transferProgress = nil
                self.transferStats = nil
                self.loadFiles(at: self.currentPath)
            }
            
        case .disposing:
            DispatchQueue.main.async {
                self.connectionState = .disconnected
                self.files = []
                self.navigationStack = []
                self.selectedStorage = nil
                self.transferProgress = nil
                self.transferStats = nil
                self.errorMessage = nil
                self.isLoading = false
                self.cachedDeviceInfo = nil
            }
            operation = .none
            
        case .none:
            break
        }
    }
    
    // MARK: – Device Connection
    func connectDevice() {
        connectionState = .connecting
        files = []
        navigationStack = []
        selectedStorage = nil
        errorMessage = nil
        isLoading = false
        operation = .initializing
        
        KalamInitialize(CallbackRouter.done)
    }
    
    func disconnect() {
        operation = .disposing
        connectionState = .disconnected
        files = []
        navigationStack = []
        selectedStorage = nil
        isLoading = false
        transferProgress = nil
        finishTransferCompletion(errorString: "Disconnected")
        errorMessage = nil
        KalamDispose(CallbackRouter.done)
    }
    
    // MARK: – USB Hotplug & Retry Logic
    private let maxRetryCount: Int = 1
    private let retryDelay: TimeInterval = 2.0
    private let initialCheckDelay: TimeInterval = 1.5  // Initial delay before checking connection status
    
    /// Handles USB device attachment/detachment events
    private func handleUSBEvent(attached: Bool) {
        print("KalamMTPManager: USB event - attached: \(attached), current operation: \(operation), ignoring: \(shouldIgnoreUSBEvents)")
        
        // Ignore USB events during transfer operations to prevent interruption
        if shouldIgnoreUSBEvents {
            print("KalamMTPManager: Ignoring USB event - user set flag")
            return
        }
        
        if case .downloading = operation {
            print("KalamMTPManager: Ignoring USB event - download in progress")
            return
        }
        if case .uploading = operation {
            print("KalamMTPManager: Ignoring USB event - upload in progress")
            return
        }
        
        if attached {
            // Device attached: attempt connection
            print("KalamMTPManager: Device attached, attempting connection...")
            hotplugRetryCount = 0
            retryTimer?.invalidate()
            retryTimer = nil
            attemptConnectWithRetry()
        } else {
            // Device detached: disconnect
            print("KalamMTPManager: Device detached, disconnecting...")
            retryTimer?.invalidate()
            retryTimer = nil
            hotplugRetryCount = 0
            disconnect()
        }
    }
    
    /// Attempts to connect with retry logic
    private func attemptConnectWithRetry() {
        // Check if already connected
        if case .connected = connectionState {
            print("KalamMTPManager: Already connected, skipping retry")
            hotplugRetryCount = 0
            return
        }
        
        // Attempt connection
        connectDevice()
        
        // Register to monitor for success/failure
        // We'll check the connection state after a delay to allow device initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + initialCheckDelay) { [weak self] in
            self?.checkConnectionAndRetry()
        }
    }
    
    /// Checks if connection succeeded, retries if needed
    private func checkConnectionAndRetry() {
        // If connected, reset retry count and return
        if case .connected = connectionState {
            print("KalamMTPManager: Connection successful, retry count reset")
            hotplugRetryCount = 0
            return
        }
        
        // If failed, attempt retry
        hotplugRetryCount += 1
        print("KalamMTPManager: Connection failed, retry attempt \(hotplugRetryCount)/\(maxRetryCount)")
        
        if hotplugRetryCount >= maxRetryCount {
            print("KalamMTPManager: Max retries reached, giving up")
            hotplugRetryCount = 0
            return
        }
        
        // Schedule next retry
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: retryDelay, repeats: false) { [weak self] _ in
            print("KalamMTPManager: Attempting retry \(self?.hotplugRetryCount ?? 0 + 1)...")
            self?.attemptConnectWithRetry()
        }
    }
    
    // MARK: – Navigation
    func navigate(to directory: MTPFile) {
        guard directory.isDirectory else { return }
        let newPath = currentPath == "/" ? "/\(directory.name)" : "\(currentPath)/\(directory.name)"
        navigationStack.append(newPath)
        loadFiles(at: newPath)
    }
    
    func navigateBack() {
        guard canGoBack else { return }
        navigationStack.removeLast()
        loadFiles(at: currentPath)
    }
    
    func navigate(toIndex index: Int) {
        guard index < navigationStack.count else { return }
        navigationStack = Array(navigationStack.prefix(index + 1))
        loadFiles(at: currentPath)
    }
    
    // MARK: – File Listing
    func loadFiles(at path: String) {
        guard let storage = selectedStorage else { return }
        guard storage.id != "" else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = true
        }
        
        let storageId = self.uint32FromStorageId(storage.id)
        let skipHiddenFiles = true
        
        let input: [String: Any] = [
            "storageId": Int(storageId),
            "fullPath": path,
            "recursive": false,
            "skipDisallowedFiles": false,
            "skipHiddenFiles": skipHiddenFiles
        ]
        
        guard let jsonString = self.toJsonString(input) else {
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false
            }
            return
        }
        
        operation = .walking
        jsonString.withCString { ptr in
            KalamWalk(ptr, CallbackRouter.done)
        }
    }
    
    // MARK: – Transfer
    func download(files: [MTPFile], destinationURL: URL) {
        guard !files.isEmpty else { return }
        guard let storage = selectedStorage else { return }
        
        let storageId = self.uint32FromStorageId(storage.id)
        let sources = files.map(\.path)
        let destination = destinationURL.path
        
        DispatchQueue.main.async { [weak self] in
            self?.transferProgress = 0
        }
        beginSecurityScopedAccess(destinationURL: destinationURL)
        
        let preprocessFiles = true
        
        let input: [String: Any] = [
            "storageId": Int(storageId),
            "sources": sources,
            "destination": destination,
            "preprocessFiles": preprocessFiles
        ]
        
        guard let jsonString = toJsonString(input) else {
            DispatchQueue.main.async { [weak self] in
                self?.transferProgress = nil
            }
            endSecurityScopedAccess()
            return
        }
        operation = .downloading
        DispatchQueue.global(qos: .userInitiated).async {
            jsonString.withCString { ptr in
                KalamDownloadFiles(ptr, CallbackRouter.preprocess, CallbackRouter.progress, CallbackRouter.done)
            }
        }
    }
    
    func upload(sourceURLs: [URL]) {
        guard !sourceURLs.isEmpty else { return }
        guard let storage = selectedStorage else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.transferProgress = 0
        }
        beginSecurityScopedAccess(sourceURLs: sourceURLs)
        let storageId = uint32FromStorageId(storage.id)
        let sources = sourceURLs.map(\.path)
        let destination = currentPath
        
        let preprocessFiles = true
        
        let input: [String: Any] = [
            "storageId": Int(storageId),
            "sources": sources,
            "destination": destination,
            "preprocessFiles": preprocessFiles
        ]
        
        guard let jsonString = toJsonString(input) else {
            DispatchQueue.main.async { [weak self] in
                self?.transferProgress = nil
            }
            endSecurityScopedAccess()
            return
        }
        operation = .uploading
        DispatchQueue.global(qos: .userInitiated).async {
            jsonString.withCString { ptr in
                KalamUploadFiles(ptr, CallbackRouter.preprocess, CallbackRouter.progress, CallbackRouter.done)
            }
        }
    }
    
    func downloadPromise(file: MTPFile, to destinationFolderURL: URL, completion: @escaping (Error?) -> Void) {
        if case .downloading = operation {
            completion(NSError(domain: "KalamMTPManager.Transfer", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Another transfer is already running."
            ]))
            return
        }
        if case .uploading = operation {
            completion(NSError(domain: "KalamMTPManager.Transfer", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Another transfer is already running."
            ]))
            return
        }
        guard let storage = selectedStorage else {
            completion(NSError(domain: "KalamMTPManager.Transfer", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "No storage selected."
            ]))
            return
        }
        
        transferCompletion = completion
        DispatchQueue.main.async { [weak self] in
            self?.transferProgress = 0
        }
        
        let storageId = self.uint32FromStorageId(storage.id)
        let sources = [file.path]
        let destination = destinationFolderURL.path
        let preprocessFiles = true
        
        let input: [String: Any] = [
            "storageId": Int(storageId),
            "sources": sources,
            "destination": destination,
            "preprocessFiles": preprocessFiles
        ]
        
        guard let jsonString = toJsonString(input) else {
            DispatchQueue.main.async { [weak self] in
                self?.transferProgress = nil
            }
            finishTransferCompletion(errorString: "Failed to encode download payload.")
            return
        }
        
        operation = .downloading
        DispatchQueue.global(qos: .userInitiated).async {
            jsonString.withCString { ptr in
                KalamDownloadFiles(ptr, CallbackRouter.preprocess, CallbackRouter.progress, CallbackRouter.done)
            }
        }
    }
    
    func deleteFiles(_ filesToDelete: [MTPFile]) {
        guard !filesToDelete.isEmpty else { return }
        guard let storage = selectedStorage else { return }
        
        let storageId = uint32FromStorageId(storage.id)
        let filePaths = filesToDelete.map(\.path)
        
        let input: [String: Any] = [
            "storageId": Int(storageId),
            "files": filePaths
        ]
        
        guard let jsonString = toJsonString(input) else { return }
        operation = .deleting
        jsonString.withCString { ptr in
            KalamDeleteFile(ptr, CallbackRouter.done)
        }
    }
    
    func createFolder(named name: String) {
        guard let storage = selectedStorage else { return }
        let storageId = uint32FromStorageId(storage.id)
        let fullPath = currentPath == "/" ? "/\(name)" : "\(currentPath)/\(name)"
        
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = true
        }
        
        let input: [String: Any] = [
            "storageId": Int(storageId),
            "fullPath": fullPath
        ]
        guard let jsonString = toJsonString(input) else { return }
        operation = .makingDirectory
        jsonString.withCString { ptr in
            KalamMakeDirectory(ptr, CallbackRouter.done)
        }
    }
    
    // MARK: – Helpers
    private func isDeviceDisconnectedError(_ error: String) -> Bool {
        // Electron uses `errorType` to detect device changed / lost device.
        // Our `parseEnvelopeErrorOnly` may format it as: `ErrorDeviceChanged: ...`
        return error.contains("ErrorDeviceChanged") || error.contains("LIBUSB_ERROR_NO_DEVICE")
    }
    
    private func handleDeviceDisconnected() {
        connectionState = .disconnected
        files = []
        navigationStack = []
        selectedStorage = nil
        isLoading = false
        transferProgress = nil
        finishTransferCompletion(errorString: "Device disconnected.")
        errorMessage = nil
    }
    
    private func beginSecurityScopedAccess(sourceURLs: [URL]) {
        scopedSourceURLs = sourceURLs.filter { $0.startAccessingSecurityScopedResource() }
    }
    
    private func beginSecurityScopedAccess(destinationURL: URL) {
        if destinationURL.startAccessingSecurityScopedResource() {
            scopedDestinationURL = destinationURL
        }
    }
    
    private func endSecurityScopedAccess() {
        scopedSourceURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        scopedSourceURLs = []
        scopedDestinationURL?.stopAccessingSecurityScopedResource()
        scopedDestinationURL = nil
    }
    
    private func finishTransferCompletion(errorString: String?) {
        endSecurityScopedAccess()
        guard let completion = transferCompletion else { return }
        transferCompletion = nil
        if let errorString {
            completion(NSError(domain: "KalamMTPManager.Transfer", code: 3, userInfo: [
                NSLocalizedDescriptionKey: errorString
            ]))
        } else {
            completion(nil)
        }
    }
    
    private func fetchStorages() {
        operation = .fetchingStorages
        KalamFetchStorages(CallbackRouter.done)
    }
    
    private func uint32FromStorageId(_ storageId: String) -> UInt32 {
        if let v = UInt32(storageId) { return v }
        // Some storages may have non-numeric IDs; best-effort fallback.
        return 0
    }
    
    private func toJsonString(_ object: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(object) else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: []) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    private func dataFromAny(_ any: Any) -> Data {
        // In Foundation, `NSJSONSerialization` sometimes directly throws/triggers exceptions
        // for non-JSON container types, try?/Catch may not be able to catch.
        // Use isValidJSONObject for strong verification to avoid the collapse of empty dir or other cases.
        guard JSONSerialization.isValidJSONObject(any) else { return Data() }
        return (try? JSONSerialization.data(withJSONObject: any, options: [])) ?? Data()
    }
    
    private func parseEnvelope(_ jsonString: String) -> (error: String?, data: Any?) {
        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: []),
              let dict = obj as? [String: Any]
        else {
            return ("Invalid kalam JSON", nil)
        }
        
        let errorString = (dict["error"] as? String) ?? ""
        // Electron treats `errorType` as `stderr`.
        let errorTypeString = (dict["errorType"] as? String) ?? ""
        let dataAny = dict["data"]
        
        if !errorString.isEmpty && !errorTypeString.isEmpty {
            return ("\(errorTypeString): \(errorString)", dataAny)
        }
        if !errorString.isEmpty {
            return (errorString, dataAny)
        }
        if !errorTypeString.isEmpty {
            return (errorTypeString, dataAny)
        }
        return (nil, dataAny)
    }
    
    private func parseEnvelopeErrorOnly(_ jsonString: String) -> String? {
        let (error, _) = parseEnvelope(jsonString)
        return error
    }
    
    private func parseEnvelopeData(_ jsonString: String) -> Any? {
        let (_, data) = parseEnvelope(jsonString)
        return data
    }
    
    private func parseDeviceInfo(_ any: Any) -> (name: String, manufacturer: String)? {
        // Data structure from Go's send_to_js: { mtpDeviceInfo: {...}, usbDeviceInfo: {...} }
        guard let dict = any as? [String: Any] else { return nil }
        
        // Try to get from mtpDeviceInfo first (MTP protocol info)
        if let mtpInfo = dict["mtpDeviceInfo"] as? [String: Any] {
            let model = mtpInfo["Model"] as? String ?? ""
            let manufacturer = mtpInfo["Manufacturer"] as? String ?? ""
            
            // If we have a model, use it along with manufacturer
            if !model.isEmpty || !manufacturer.isEmpty {
                return (name: model.isEmpty ? "MTP Device" : model, manufacturer: manufacturer)
            }
        }
        
        // Fallback to usbDeviceInfo
        if let usbInfo = dict["usbDeviceInfo"] as? [String: Any] {
            let deviceName = usbInfo["DeviceName"] as? String ?? ""
            let manufacturer = usbInfo["Manufacturer"] as? String ?? ""
            
            if !deviceName.isEmpty || !manufacturer.isEmpty {
                return (name: deviceName.isEmpty ? "Android Device" : deviceName, manufacturer: manufacturer)
            }
        }
        
        return nil
    }
    
    private func parseStorages(_ any: Any) -> [MTPStorage] {
        guard let list = any as? [[String: Any]] else { return [] }
        return list.compactMap { storage in
            let sidInt = int64FromAny(storage["Sid"]) ?? int64FromAny(storage["sid"]) ?? 0
            let id = String(UInt32(max(sidInt, 0)))
            
            let infoAny = storage["Info"] as? [String: Any] ?? storage["info"] as? [String: Any]
            let name = infoAny?["StorageDescription"] as? String ?? "Storage"
            
            let freeSpace = int64FromAny(infoAny?["FreeSpaceInBytes"]) ?? 0
            let totalSpace = int64FromAny(infoAny?["MaxCapability"]) ?? 0
            
            return MTPStorage(
                id: id,
                name: name,
                freeSpace: freeSpace,
                totalSpace: totalSpace
            )
        }
    }
    
    private func int64FromAny(_ any: Any?) -> Int64? {
        switch any {
        case let v as Int64: return v
        case let v as UInt64: return Int64(v)
        case let v as Int: return Int64(v)
        case let v as Double: return Int64(v)
        case let v as Float: return Int64(v)
        case let v as NSNumber: return v.int64Value
        default: return nil
        }
    }
    
    private func parseKalamDate(_ dateAdded: String) -> Date? {
        // Format matches `send_to_js/constants.go`:
        // "2006-01-02T15:04:05.000Z"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return formatter.date(from: dateAdded)
    }
    
    private struct KalamWalkFileInfo: Decodable {
        let size: Int64
        let isFolder: Bool
        let dateAdded: String
        let name: String
        let path: String
        let extension_: String
        let objectId: UInt32
        
        private enum CodingKeys: String, CodingKey {
            case size
            case isFolder
            case dateAdded
            case name
            case path
            case extension_ = "extension"
            case objectId
        }
    }
    
    private struct TransferSizeInfo: Decodable {
        let total: Int64?
        let sent: Int64?
        let progress: Float?
    }
    // MARK: - Transfer Progress Decoding
    
    private func decodeFullTransferProgress(from dataAny: Any) -> TransferProgressData? {
        let d = dataFromAny(dataAny)
        guard !d.isEmpty else { return nil }
        return try? JSONDecoder().decode(TransferProgressData.self, from: d)
    }
    
    private func mapUSBProtocol(from name: String) -> USBProtocol {
        switch name {
        case "USB 2.0": return .usb20
        case "USB 3.0": return .usb30
        case "USB 3.1": return .usb31
        case "USB 3.2": return .usb32
        default: return .unknown
        }
    }
}
