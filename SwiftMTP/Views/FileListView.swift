import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct FileListView: View {
    @ObservedObject var manager: KalamMTPManager
    @Binding var selection: Set<MTPFile.ID>
    var onDoubleClick: (MTPFile) -> Void

    @State private var isShowingNewFolderDialog = false
    @State private var showError = false
    @State private var isShowingReplaceAlert = false
    @State private var newFolderName = "Untitled Folder"
    @State private var sortState = FileListSortState(column: .name, ascending: true)
    @State private var urls: [URL] = []
    @State private var pendingUploadURLs: [URL] = []
    @State private var isShowingExportReplaceAlert = false
    @State private var pendingExportDestinationURL: URL?
    @State private var pendingExportFiles: [MTPFile] = []
    @State private var sheetController: NSWindowController?

    var body: some View {
        Group {
            if !manager.connectionState.isConnected {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if manager.isLoading {
                loadingView
            } else {
                fileList
            }
        }
        .alert("New Folder", isPresented: $isShowingNewFolderDialog) {
            TextField("Folder Name", text: $newFolderName)
            Button("Create") {
                manager.createFolder(named: newFolderName)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for this new folder.")
        }
        .alert("Error", isPresented: $showError) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text("path issue")
        }
        .alert(String(localized: "Replace and merge the existing items?"), isPresented: $isShowingReplaceAlert) {
            Button(String(localized: "Replace")) {
                guard !pendingUploadURLs.isEmpty else { return }
                urls = pendingUploadURLs
                pendingUploadURLs.removeAll()
                showImportSheet()
            }
            Button("Cancel", role: .cancel) {
                pendingUploadURLs.removeAll()
            }
        }
        .alert(String(localized: "Replace and merge the existing items?"), isPresented: $isShowingExportReplaceAlert) {
            Button(String(localized: "Replace")) {
                guard let destinationURL = pendingExportDestinationURL else { return }
                guard !pendingExportFiles.isEmpty else { return }
                manager.download(files: pendingExportFiles, destinationURL: destinationURL)
                pendingExportFiles.removeAll()
                pendingExportDestinationURL = nil
            }
            Button("Cancel", role: .cancel) {
                pendingExportFiles.removeAll()
                pendingExportDestinationURL = nil
            }
        }
    }

    private func showImportSheet() {
        guard let window = NSApplication.shared.mainWindow ?? NSApplication.shared.windows.first(where: { $0.isVisible }) else {
            return
        }
        
        let contentView = ImportDialogContent(
            urls: urls,
            onCancel: { [self] in
                DispatchQueue.main.async {
                    self.closeImportSheet()
                }
            },
            onConfirm: { [self] in
                self.manager.upload(sourceURLs: self.urls)
                self.urls.removeAll()
                DispatchQueue.main.async {
                    self.closeImportSheet()
                }
            }
        )
        
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 420, height: 300)
        
        let sheetWindow = NSWindow(contentViewController: hostingController)
        sheetWindow.styleMask = [.titled]
        sheetWindow.title = String(localized: "Confirm import?")
        
        window.beginSheet(sheetWindow) { response in
            self.sheetController = nil
        }
        
        self.sheetController = NSWindowController(window: sheetWindow)
    }

    private func closeImportSheet() {
        guard let sheetWindow = sheetController?.window else { return }
//        guard let parentWindow = NSApplication.shared.keyWindow else { return }
//        parentWindow.endSheet(sheetWindow)
        if let parentWindow = sheetWindow.sheetParent {
            parentWindow.endSheet(sheetWindow)
        } else {
//            sheetWindow.close()
            return
        }
    }

    private func handleImportRequest(_ droppedURLs: [URL]) {
        if droppedURLs.isEmpty {
            showError = true
            return
        }
        if manager.hasConflictingItems(for: droppedURLs) {
            pendingUploadURLs = droppedURLs
            isShowingReplaceAlert = true
            return
        }
        urls = droppedURLs
        showImportSheet()
    }

    private func handleExportRequest(_ files: [MTPFile]) {
        guard !files.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = String(localized: "Export Here")
        if panel.runModal() == .OK, let url = panel.url {
            if hasExportConflicts(files: files, destinationURL: url) {
                pendingExportFiles = files
                pendingExportDestinationURL = url
                isShowingExportReplaceAlert = true
                return
            }
            manager.download(files: files, destinationURL: url)
        }
    }

    private func hasExportConflicts(files: [MTPFile], destinationURL: URL) -> Bool {
        for file in files {
            let targetURL = destinationURL.appendingPathComponent(file.name)
            if FileManager.default.fileExists(atPath: targetURL.path) {
                return true
            }
        }
        return false
    }

    private var fileList: some View {
        ZStack {
            FileListTableRepresentable(
                manager: manager,
                files: sortedFiles,
                selection: $selection,
                sortState: $sortState,
                onDoubleClick: onDoubleClick,
                onNewFolder: {
                    newFolderName = "Untitled Folder"
                    isShowingNewFolderDialog = true
                },
                onOpenSelected: { file in
                    onDoubleClick(file)
                },
                onExportSelected: { selectedFiles in
                    handleExportRequest(selectedFiles)
                },
                onDropExternalFiles: { droppedURLs in
                    handleImportRequest(droppedURLs)
                }
            )

            if sortedFiles.isEmpty {
                emptyView
                    .allowsHitTesting(false)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Loading files…")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("This folder is empty")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension FileListView {
    var sortedFiles: [MTPFile] {
        manager.files.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            let comparison = compare(lhs, rhs, by: sortState.column)
            if comparison == .orderedSame {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            if sortState.ascending {
                return comparison == .orderedAscending
            }
            return comparison == .orderedDescending
        }
    }

    func compare(_ lhs: MTPFile, _ rhs: MTPFile, by column: FileListColumn) -> ComparisonResult {
        switch column {
        case .name:
            return lhs.name.localizedStandardCompare(rhs.name)
        case .dateModified:
            if lhs.dateModified == rhs.dateModified { return .orderedSame }
            return lhs.dateModified < rhs.dateModified ? .orderedAscending : .orderedDescending
        case .size:
            if lhs.size == rhs.size { return .orderedSame }
            return lhs.size < rhs.size ? .orderedAscending : .orderedDescending
        case .kind:
            return lhs.kind.localizedStandardCompare(rhs.kind)
        }
    }
}

private enum FileListColumn: String, CaseIterable {
    case name = "name"
    case dateModified = "dateModified"
    case size = "size"
    case kind = "kind"
}

private struct FileListSortState: Equatable {
    var column: FileListColumn
    var ascending: Bool
}

private struct FileListTableRepresentable: NSViewRepresentable {
    let manager: KalamMTPManager
    let files: [MTPFile]
    @Binding var selection: Set<MTPFile.ID>
    @Binding var sortState: FileListSortState

    let onDoubleClick: (MTPFile) -> Void
    let onNewFolder: () -> Void
    let onOpenSelected: (MTPFile) -> Void
    let onExportSelected: ([MTPFile]) -> Void
    let onDropExternalFiles: ([URL]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        let tableView = ContextMenuTableView(frame: .zero)
        tableView.focusRingType = .none
        tableView.allowsMultipleSelection = true
        tableView.allowsEmptySelection = true
        tableView.allowsColumnReordering = false
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.gridStyleMask = []
        tableView.intercellSpacing = NSSize(width: 4, height: 2)
        tableView.rowHeight = 24
        tableView.headerView = NSTableHeaderView()
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        tableView.selectionHighlightStyle = .regular
        tableView.usesAutomaticRowHeights = false
        tableView.allowsTypeSelect = true
        tableView.target = context.coordinator
        tableView.doubleAction = #selector(Coordinator.handleDoubleClick(_:))
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.registerForDraggedTypes([.fileURL])
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
        tableView.setDraggingSourceOperationMask([], forLocal: true)

        for spec in ColumnSpec.defaultSpecs {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(spec.id.rawValue))
            column.title = spec.title
            column.width = spec.width
            column.minWidth = spec.minWidth
            column.maxWidth = spec.maxWidth
            column.resizingMask = .userResizingMask
            column.sortDescriptorPrototype = NSSortDescriptor(key: spec.id.rawValue, ascending: true)
            tableView.addTableColumn(column)
        }

        tableView.menuProvider = { [weak coordinator = context.coordinator] clickedRow in
            coordinator?.menu(for: clickedRow)
        }

        scrollView.documentView = tableView

        context.coordinator.tableView = tableView
        context.coordinator.applySortDescriptorIfNeeded()
        context.coordinator.applySelectionIfNeeded()

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tableView = nsView.documentView as? ContextMenuTableView else { return }

        context.coordinator.parent = self
        context.coordinator.tableView = tableView
        tableView.usesAlternatingRowBackgroundColors = !files.isEmpty
        context.coordinator.applySortDescriptorIfNeeded()
        tableView.reloadData()
        context.coordinator.applySelectionIfNeeded()
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSFilePromiseProviderDelegate {
        var parent: FileListTableRepresentable
        weak var tableView: NSTableView?

        private var isSyncingSelection = false
        private var draggedFiles: [MTPFile] = []  // Track files for multi-select drag
        private var isDraggingMultiple = false    // Flag for multi-file drag
        
        private static let sharedPromiseQueue: OperationQueue = {
            let queue = OperationQueue()
            queue.maxConcurrentOperationCount = 1
            queue.qualityOfService = .userInitiated
            return queue
        }()

        private lazy var dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter
        }()

        init(parent: FileListTableRepresentable) {
            self.parent = parent
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            parent.files.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row >= 0, row < parent.files.count else { return nil }
            guard let tableColumn else { return nil }
            let file = parent.files[row]
            guard let column = FileListColumn(rawValue: tableColumn.identifier.rawValue) else { return nil }

            switch column {
            case .name:
                return makeNameCell(for: file, tableView: tableView)
            case .dateModified:
                return makeTextCell(
                    identifier: "DateCell",
                    text: dateFormatter.string(from: file.dateModified),
                    alignment: .left,
                    font: .systemFont(ofSize: 11),
                    tableView: tableView
                )
            case .size:
                return makeTextCell(
                    identifier: "SizeCell",
                    text: file.displaySize,
                    alignment: .right,
                    font: .monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                    tableView: tableView
                )
            case .kind:
                return makeTextCell(
                    identifier: "KindCell",
                    text: file.kind,
                    alignment: .left,
                    font: .systemFont(ofSize: 11),
                    tableView: tableView
                )
            }
        }

        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            guard row >= 0, row < parent.files.count else { return nil }
            
            // Check if this is the first row of a multi-select drag
            let selectedIndexes = tableView.selectedRowIndexes
            if selectedIndexes.count > 1 && selectedIndexes.first == row {
                // This is the start of a multi-select drag
                let selectedFiles = selectedIndexes.compactMap { idx -> MTPFile? in
                    guard idx >= 0, idx < parent.files.count else { return nil }
                    return parent.files[idx]
                }
                draggedFiles = selectedFiles
                isDraggingMultiple = true
                
                // Return a provider for the first file only
                let firstFile = parent.files[row]
                let type: UTType = firstFile.isDirectory ? .folder : (UTType(filenameExtension: firstFile.extension_) ?? .data)
                let provider = NSFilePromiseProvider(fileType: type.identifier, delegate: self)
                provider.userInfo = "multi" as NSString
                return provider
            } else if selectedIndexes.count == 1 {
                // Single file drag
                draggedFiles = [parent.files[row]]
                isDraggingMultiple = false
                
                let file = parent.files[row]
                let type: UTType = file.isDirectory ? .folder : (UTType(filenameExtension: file.extension_) ?? .data)
                let provider = NSFilePromiseProvider(fileType: type.identifier, delegate: self)
                provider.userInfo = file.id as NSString
                return provider
            }
            
            return nil
        }

        func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
            promiseFile(for: filePromiseProvider)?.name ?? "Untitled"
        }

        func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
            let destination = normalizedPromiseDestination(url)
            
            // Handle multi-file drag
            if isDraggingMultiple && !draggedFiles.isEmpty {
                parent.manager.download(files: draggedFiles, destinationURL: destination)
                completionHandler(nil)
                // Reset the drag state after completion
                isDraggingMultiple = false
                draggedFiles = []
                return
            }
            
            // Handle single file drag
            guard let file = promiseFile(for: filePromiseProvider) else {
                completionHandler(NSError(domain: "FileListView.Promise", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to resolve file for drag export."
                ]))
                return
            }
            parent.manager.downloadPromise(file: file, to: destination) { error in
                completionHandler(error)
                // Reset single file drag state
                self.isDraggingMultiple = false
                self.draggedFiles = []
            }
        }

        func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
            Self.sharedPromiseQueue
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !isSyncingSelection else { return }
            guard let tableView else { return }
            let selectedIDs = tableView.selectedRowIndexes.compactMap { row -> MTPFile.ID? in
                guard row >= 0, row < parent.files.count else { return nil }
                return parent.files[row].id
            }
            parent.selection = Set(selectedIDs)
        }

        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
            guard let descriptor = tableView.sortDescriptors.first else { return }
            guard let key = descriptor.key, let column = FileListColumn(rawValue: key) else { return }
            let newState = FileListSortState(column: column, ascending: descriptor.ascending)
            if parent.sortState != newState {
                parent.sortState = newState
            }
        }

        func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
            guard info.draggingSource as? NSTableView !== tableView else { return [] }
            let urls = readFileURLs(from: info.draggingPasteboard)
            guard !urls.isEmpty else { return [] }
            tableView.setDropRow(-1, dropOperation: .on)
            return .copy
        }

        func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
            let urls = readFileURLs(from: info.draggingPasteboard)
            guard !urls.isEmpty else { return false }
            parent.onDropExternalFiles(urls)
            return true
        }

        func applySortDescriptorIfNeeded() {
            guard let tableView else { return }
            let current = tableView.sortDescriptors.first
            let target = NSSortDescriptor(key: parent.sortState.column.rawValue, ascending: parent.sortState.ascending)
            if current?.key == target.key && current?.ascending == target.ascending {
                return
            }
            tableView.sortDescriptors = [target]
        }

        func applySelectionIfNeeded() {
            guard let tableView else { return }
            var target = IndexSet()
            for (index, file) in parent.files.enumerated() where parent.selection.contains(file.id) {
                target.insert(index)
            }
            if tableView.selectedRowIndexes == target {
                return
            }
            isSyncingSelection = true
            tableView.selectRowIndexes(target, byExtendingSelection: false)
            isSyncingSelection = false
        }

        private var selectedContextFiles: [MTPFile] {
            guard let tableView else { return [] }
            return tableView.selectedRowIndexes.compactMap { row in
                guard row >= 0, row < parent.files.count else { return nil }
                return parent.files[row]
            }
        }

        func menu(for clickedRow: Int) -> NSMenu {
            if let tableView {
                if clickedRow >= 0 {
                    if !tableView.selectedRowIndexes.contains(clickedRow) {
                        isSyncingSelection = true
                        tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
                        isSyncingSelection = false
                        tableViewSelectionDidChange(Notification(name: NSTableView.selectionDidChangeNotification))
                    }
                } else {
                    isSyncingSelection = true
                    tableView.deselectAll(nil)
                    isSyncingSelection = false
                    tableViewSelectionDidChange(Notification(name: NSTableView.selectionDidChangeNotification))
                }
            }

            let selectedFiles = selectedContextFiles
            let menu = NSMenu()

            // New Folder always available
            let newFolder = NSMenuItem(title: String(localized: "New Folder"), action: #selector(handleNewFolder), keyEquivalent: "")
            newFolder.target = self
            menu.addItem(newFolder)
            menu.addItem(NSMenuItem.separator())

            if !selectedFiles.isEmpty {
                // Open only for a single selected folder
                if selectedFiles.count == 1, let first = selectedFiles.first, first.isDirectory {
                    let openItem = NSMenuItem(title: String(localized: "Open"), action: #selector(handleOpenSelected), keyEquivalent: "")
                    openItem.target = self
                    menu.addItem(openItem)
                }

                let exportItem = NSMenuItem(title: String(localized: "Export"), action: #selector(handleExportSelected), keyEquivalent: "")
                exportItem.target = self
                menu.addItem(exportItem)
            }

            return menu
        }

        @objc func handleDoubleClick(_ sender: Any?) {
            guard let tableView else { return }
            let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
            guard row >= 0, row < parent.files.count else { return }
            parent.onDoubleClick(parent.files[row])
        }

        @objc private func handleNewFolder() {
            parent.onNewFolder()
        }

        @objc private func handleOpenSelected() {
            guard let first = selectedRows().first else { return }
            guard first >= 0, first < parent.files.count else { return }
            parent.onOpenSelected(parent.files[first])
        }

        @objc private func handleExportSelected() {
            let selectedFiles = selectedContextFiles
            guard !selectedFiles.isEmpty else { return }
            parent.onExportSelected(selectedFiles)
        }

        private func selectedRows() -> [Int] {
            guard let tableView else { return [] }
            return tableView.selectedRowIndexes.map { $0 }
        }

        private func makeNameCell(for file: MTPFile, tableView: NSTableView) -> NSView {
            let identifier = NSUserInterfaceItemIdentifier("NameCell")
            let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView ?? {
                let container = NSTableCellView()
                container.identifier = identifier

                let iconView = NSImageView()
                iconView.translatesAutoresizingMaskIntoConstraints = false
                iconView.imageScaling = .scaleProportionallyDown

                let label = NSTextField(labelWithString: "")
                label.translatesAutoresizingMaskIntoConstraints = false
                label.font = .systemFont(ofSize: 12)
                label.lineBreakMode = .byTruncatingMiddle
                label.maximumNumberOfLines = 1

                container.imageView = iconView
                container.textField = label
                container.addSubview(iconView)
                container.addSubview(label)

                NSLayoutConstraint.activate([
                    iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
                    iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                    iconView.widthAnchor.constraint(equalToConstant: 18),
                    iconView.heightAnchor.constraint(equalToConstant: 16),

                    label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
                    label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
                    label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
                ])

                return container
            }()

            cell.imageView?.image = getThumbnailIcon(for: file)
            cell.textField?.stringValue = file.name
            cell.textField?.textColor = .labelColor
            return cell
        }

        private func makeTextCell(identifier: String, text: String, alignment: NSTextAlignment, font: NSFont, tableView: NSTableView) -> NSView {
            let nsIdentifier = NSUserInterfaceItemIdentifier(identifier)
            let cell = tableView.makeView(withIdentifier: nsIdentifier, owner: nil) as? NSTableCellView ?? {
                let container = NSTableCellView()
                container.identifier = nsIdentifier

                let label = NSTextField(labelWithString: "")
                label.translatesAutoresizingMaskIntoConstraints = false
                label.maximumNumberOfLines = 1
                label.lineBreakMode = .byTruncatingTail

                container.textField = label
                container.addSubview(label)

                NSLayoutConstraint.activate([
                    label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
                    label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
                    label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
                ])
                return container
            }()

            cell.textField?.stringValue = text
            cell.textField?.alignment = alignment
            cell.textField?.font = font
            cell.textField?.textColor = .labelColor
            return cell
        }

        private func readFileURLs(from pasteboard: NSPasteboard) -> [URL] {
            let options: [NSPasteboard.ReadingOptionKey: Any] = [
                .urlReadingFileURLsOnly: true
            ]
            let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [NSURL] ?? []
            return objects.map { $0 as URL }
        }

        private func getThumbnailIcon(for file: MTPFile) -> NSImage {
            if file.isDirectory {
                return NSWorkspace.shared.icon(for: .folder)
            }
            
            let ext = file.extension_.lowercased()
            
            // Try to get icon using file extension with UTType
            if !ext.isEmpty {
                if let utType = UTType(filenameExtension: ext) {
                    if let icon = NSWorkspace.shared.icon(for: utType) as NSImage? {
                        return icon
                    }
                }
            }
            
            // Fallback to generic file icon
            return NSWorkspace.shared.icon(for: .data)
        }

        private func promiseFile(for provider: NSFilePromiseProvider) -> MTPFile? {
            guard let fileID = provider.userInfo as? NSString else { return nil }
            return parent.files.first { $0.id == fileID as String }
        }

        private func normalizedPromiseDestination(_ url: URL) -> URL {
            var isDirectory = ObjCBool(false)
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return url
            }
            // Some drag destinations provide the final promised-item URL instead of a writable directory.
            // For Kalam import we need the parent directory as destination.
            return url.deletingLastPathComponent()
        }

        private func iconTint(for file: MTPFile) -> NSColor {
            let ext = file.extension_.lowercased()
            switch ext {
            case "jpg", "jpeg", "png", "gif", "heic", "webp":
                return NSColor.systemBlue.withAlphaComponent(0.92)
            case "mp4", "mov", "avi", "mkv", "3gp":
                return NSColor.systemRed.withAlphaComponent(0.84)
            case "mp3", "aac", "flac", "wav", "m4a":
                return NSColor.systemPurple.withAlphaComponent(0.84)
            case "pdf":
                return NSColor.systemIndigo.withAlphaComponent(0.86)
            case "zip", "rar", "7z":
                return NSColor.systemOrange.withAlphaComponent(0.86)
            case "apk":
                return NSColor.systemGreen.withAlphaComponent(0.84)
            case "":
                return NSColor.controlAccentColor.withAlphaComponent(0.65)
            default:
                return NSColor.secondaryLabelColor.withAlphaComponent(0.85)
            }
        }
    }
}

private struct ColumnSpec {
    let id: FileListColumn
    let title: String
    let minWidth: CGFloat
    let width: CGFloat
    let maxWidth: CGFloat

    static let defaultSpecs: [ColumnSpec] = [
        ColumnSpec(id: .name, title: String(localized: "Name"), minWidth: 220, width: 320, maxWidth: 520),
        ColumnSpec(id: .dateModified, title: String(localized: "Date Modified"), minWidth: 150, width: 180, maxWidth: 240),
        ColumnSpec(id: .size, title: String(localized: "Size"), minWidth: 80, width: 100, maxWidth: 140),
        ColumnSpec(id: .kind, title: String(localized: "Kind"), minWidth: 120, width: 160, maxWidth: 220)
    ]
}

private final class ContextMenuTableView: NSTableView {
    var menuProvider: ((Int) -> NSMenu?)?

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)
        return menuProvider?(row)
    }
}

// MARK: - ImportDialogContent (Sheet content)

private struct ImportDialogContent: View {
    let urls: [URL]
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text(String(localized: "Confirm import?"))
                .font(.headline)
                .padding(.top)

            VStack(alignment: .leading, spacing: 5) {
                Text(String(localized: "Items to be imported:"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(urls, id: \.self) { url in
                            HStack(spacing: 8) {
                                Text(url.lastPathComponent)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Spacer()
                            }
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                }
                .frame(maxHeight: 240)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .contentShape(Rectangle())
            }
            .padding(.horizontal)

            HStack(spacing: 20) {
                Button(String(localized: "Cancel")) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button(String(localized: "Import")) {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom)
        }
        .frame(minWidth: 400)
        .padding()
    }
}
