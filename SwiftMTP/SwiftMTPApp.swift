import SwiftUI

@main
struct SwiftMTPApp: App {
    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    
    @FocusedValue(\.isConnected) var isConnected
    @FocusedValue(\.isTransferActive) var isTransferActive
    @FocusedValue(\.isSelectedFilesEmpty) var isSelectedFilesEmpty
    @FocusedValue(\.isSingleFileSelected) var isSingleFileSelected
    @FocusedValue(\.showDeviceInfoAction) var showDeviceInfoAction
    @FocusedValue(\.showNewFolderAction) var showNewFolderAction
    @FocusedValue(\.showRenameAction) var showRenameAction
    @FocusedValue(\.showDeleteConfirmationAction) var showDeleteConfirmationAction
    @FocusedValue(\.connectDeviceAction) var connectDeviceAction
    @FocusedValue(\.disconnectDeviceAction) var disconnectDeviceAction
    @FocusedValue(\.isSingleItemSelected) var isSingleItemSelected
    @FocusedValue(\.openFileAction) var openFileAction
    @FocusedValue(\.quickLookAction) var quickLookAction

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .newItem) {
                Button { showNewFolderAction?() } label: { Label("New Folder", systemImage: "folder.badge.plus") }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .disabled(isConnected != true || isTransferActive == true)
                Button { openFileAction?() } label: { Label("Open", systemImage: "arrow.up.forward.app") }
                    .keyboardShortcut("o", modifiers: [.command])
                    .disabled(isConnected != true || isTransferActive == true || isSingleItemSelected != true)
                Button { showRenameAction?() } label: { Label("Rename", systemImage: "character.cursor.ibeam") }
                    .disabled(isConnected != true || isTransferActive == true || isSingleItemSelected != true)
                Button { quickLookAction?() } label: { Label("Quick Look", systemImage: "eye") }
                    .keyboardShortcut("y", modifiers: [.command])
                    .disabled(isConnected != true || isTransferActive == true || isSingleItemSelected != true)
                Button { showDeleteConfirmationAction?() } label: { Label("Delete", systemImage: "trash") }
                    .keyboardShortcut(.delete, modifiers: [.command])
                    .disabled(isConnected != true || isTransferActive == true || isSelectedFilesEmpty == true)
                
                Divider()
                
                if isConnected == true {
                    Button { disconnectDeviceAction?() } label: { Label("Disconnect Device", systemImage: "cable.connector.slash") }
                        .keyboardShortcut("e", modifiers: [.command])
                        .disabled(isTransferActive == true)
                } else {
                    Button { connectDeviceAction?() } label: { Label("Connect Device", systemImage: "cable.connector") }
                        .keyboardShortcut("k", modifiers: [.command])
                        .disabled(isConnected == true)
                }
                Button { showDeviceInfoAction?() } label: { Label("Device Info", systemImage: "info.circle") }
                    .keyboardShortcut("i", modifiers: [.command])
                    .disabled(isConnected != true || isTransferActive == true)
                
                Divider()
                
                Button { handleImportAction() } label: { Label("Import", systemImage: "iphone.and.arrow.forward.inward") }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                    .disabled(isConnected != true || isTransferActive == true)
                Button { handleExportAction() } label: { Label("Export", systemImage: "iphone.and.arrow.forward.outward") }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(isConnected != true || isTransferActive == true || isSelectedFilesEmpty == true)
                
                Divider()
                
                Button(String(localized: "Clear Preview Cache")) {
                    clearCacheAction()
                }
            }
            
            GoMenuCommands()
        }
        //.defaultSize(width: 900, height: 600)
        
        Settings {
            SettingsView()
        }
    }

    private func handleImportAction() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = String(localized: "Import")
        if panel.runModal() == .OK {
            // Post notification to trigger import in MainView
            let userInfo: [String: Any] = ["urls": panel.urls]
            NotificationCenter.default.post(name: NSNotification.Name("SwiftMTPImportAction"), object: nil, userInfo: userInfo)
        }
    }

    private func handleExportAction() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = String(localized: "Export Here")
        if panel.runModal() == .OK, let url = panel.url {
            // Post notification to trigger export in MainView
            let userInfo: [String: Any] = ["destinationURL": url]
            NotificationCenter.default.post(name: NSNotification.Name("SwiftMTPExportAction"), object: nil, userInfo: userInfo)
        }
    }

    private func clearCacheAction() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftMTP_QuickLook")
        var size: Int64 = 0
        if let enumerator = FileManager.default.enumerator(at: tempDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let attrs = try? fileURL.resourceValues(forKeys: [.fileSizeKey]), let fileSize = attrs.fileSize {
                    size += Int64(fileSize)
                }
            }
        }
        
        let sizeMB = Double(size) / 1000.0 / 1000.0
        let alert = NSAlert()
        alert.messageText = String(localized: "Clear Preview Cache")
        alert.informativeText = String(format: String(localized: "Current preview cache size is %.2f MB. Are you sure you want to clear it?"), sizeMB)
        alert.addButton(withTitle: String(localized: "Clear"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        
        if alert.runModal() == .alertFirstButtonReturn {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }
}

struct GoMenuCommands: Commands {
    @FocusedValue(\.isConnected) var isConnected
    @FocusedValue(\.canGoBack) var canGoBack
    @FocusedValue(\.navigateToPathAction) var navigateToPathAction
    @FocusedValue(\.navigateBackAction) var navigateBackAction
    @FocusedValue(\.showFolderPromptAction) var showFolderPromptAction
    
    var body: some Commands {
        CommandMenu(String(localized: "Go")) {
            Button { navigateBackAction?()} label: { Label("Enclosing Folder", systemImage: "arrow.up.folder") }
                .keyboardShortcut(.upArrow, modifiers: [.command])
                .disabled(canGoBack != true)
                
            Divider()
            
            Button { navigateToPathAction?("/DCIM") } label: { Label("Photos", systemImage: "photo.on.rectangle") }
                .disabled(isConnected != true)
            Button { navigateToPathAction?("/Download") } label: { Label("Downloads", systemImage: "arrow.down.circle") }
                .keyboardShortcut("l", modifiers: [.command, .option])
                .disabled(isConnected != true)
            Button { navigateToPathAction?("/Bluetooth") } label: { Label("Bluetooth", systemImage: "wave.3.right") }
                .disabled(isConnected != true)
            Button { navigateToPathAction?("/Pictures/Screenshots") } label: { Label("Screenshots", systemImage: "camera.viewfinder") }
                .disabled(isConnected != true)
                
            Divider()
            
            Button { showFolderPromptAction?() } label: { Label("Go to Folder...", systemImage: "arrow.forward.folder") }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(isConnected != true)
        }
    }
}

struct IsConnectedFocusedKey: FocusedValueKey { typealias Value = Bool }
struct CanGoBackFocusedKey: FocusedValueKey { typealias Value = Bool }
struct IsTransferActiveFocusedKey: FocusedValueKey { typealias Value = Bool }
struct IsSelectedFilesEmptyFocusedKey: FocusedValueKey { typealias Value = Bool }
struct IsSingleFileSelectedFocusedKey: FocusedValueKey { typealias Value = Bool }
struct NavigateToPathActionFocusedKey: FocusedValueKey { typealias Value = (String) -> Void }
struct NavigateBackActionFocusedKey: FocusedValueKey { typealias Value = () -> Void }
struct ShowFolderPromptActionFocusedKey: FocusedValueKey { typealias Value = () -> Void }
struct ShowDeviceInfoActionFocusedKey: FocusedValueKey { typealias Value = () -> Void }
struct ShowNewFolderActionFocusedKey: FocusedValueKey { typealias Value = () -> Void }
struct ShowRenameActionFocusedKey: FocusedValueKey { typealias Value = () -> Void }
struct ShowDeleteConfirmationActionFocusedKey: FocusedValueKey { typealias Value = () -> Void }
struct ConnectDeviceActionFocusedKey: FocusedValueKey { typealias Value = () -> Void }
struct DisconnectDeviceActionFocusedKey: FocusedValueKey { typealias Value = () -> Void }
struct IsSingleItemSelectedFocusedKey: FocusedValueKey { typealias Value = Bool }
struct OpenFileActionFocusedKey: FocusedValueKey { typealias Value = () -> Void }
struct QuickLookActionFocusedKey: FocusedValueKey { typealias Value = () -> Void }

extension FocusedValues {
    var isConnected: Bool? {
        get { self[IsConnectedFocusedKey.self] }
        set { self[IsConnectedFocusedKey.self] = newValue }
    }
    var canGoBack: Bool? {
        get { self[CanGoBackFocusedKey.self] }
        set { self[CanGoBackFocusedKey.self] = newValue }
    }
    var isTransferActive: Bool? {
        get { self[IsTransferActiveFocusedKey.self] }
        set { self[IsTransferActiveFocusedKey.self] = newValue }
    }
    var isSelectedFilesEmpty: Bool? {
        get { self[IsSelectedFilesEmptyFocusedKey.self] }
        set { self[IsSelectedFilesEmptyFocusedKey.self] = newValue }
    }
    var isSingleFileSelected: Bool? {
        get { self[IsSingleFileSelectedFocusedKey.self] }
        set { self[IsSingleFileSelectedFocusedKey.self] = newValue }
    }
    var navigateToPathAction: ((String) -> Void)? {
        get { self[NavigateToPathActionFocusedKey.self] }
        set { self[NavigateToPathActionFocusedKey.self] = newValue }
    }
    var navigateBackAction: (() -> Void)? {
        get { self[NavigateBackActionFocusedKey.self] }
        set { self[NavigateBackActionFocusedKey.self] = newValue }
    }
    var showFolderPromptAction: (() -> Void)? {
        get { self[ShowFolderPromptActionFocusedKey.self] }
        set { self[ShowFolderPromptActionFocusedKey.self] = newValue }
    }
    var showDeviceInfoAction: (() -> Void)? {
        get { self[ShowDeviceInfoActionFocusedKey.self] }
        set { self[ShowDeviceInfoActionFocusedKey.self] = newValue }
    }
    var showNewFolderAction: (() -> Void)? {
        get { self[ShowNewFolderActionFocusedKey.self] }
        set { self[ShowNewFolderActionFocusedKey.self] = newValue }
    }
    var showRenameAction: (() -> Void)? {
        get { self[ShowRenameActionFocusedKey.self] }
        set { self[ShowRenameActionFocusedKey.self] = newValue }
    }
    var showDeleteConfirmationAction: (() -> Void)? {
        get { self[ShowDeleteConfirmationActionFocusedKey.self] }
        set { self[ShowDeleteConfirmationActionFocusedKey.self] = newValue }
    }
    var connectDeviceAction: (() -> Void)? {
        get { self[ConnectDeviceActionFocusedKey.self] }
        set { self[ConnectDeviceActionFocusedKey.self] = newValue }
    }
    var disconnectDeviceAction: (() -> Void)? {
        get { self[DisconnectDeviceActionFocusedKey.self] }
        set { self[DisconnectDeviceActionFocusedKey.self] = newValue }
    }
    var isSingleItemSelected: Bool? {
        get { self[IsSingleItemSelectedFocusedKey.self] }
        set { self[IsSingleItemSelectedFocusedKey.self] = newValue }
    }
    var openFileAction: (() -> Void)? {
        get { self[OpenFileActionFocusedKey.self] }
        set { self[OpenFileActionFocusedKey.self] = newValue }
    }
    var quickLookAction: (() -> Void)? {
        get { self[QuickLookActionFocusedKey.self] }
        set { self[QuickLookActionFocusedKey.self] = newValue }
    }
}
