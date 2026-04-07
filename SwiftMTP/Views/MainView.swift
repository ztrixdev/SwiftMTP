import SwiftUI
import Foundation
import AppKit

struct MainView: View {
    @StateObject private var manager = KalamMTPManager()
    @State private var selection: Set<MTPFile.ID> = []
    @State private var isShowingNewFolderDialog = false
    @State private var newFolderName = ""
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingDeviceInfo = false

    var selectedFiles: [MTPFile] {
        manager.sortedFiles.filter { selection.contains($0.id) }
    }

    var deleteDialogTitle: String {
        if selectedFiles.count == 1, let first = selectedFiles.first {
            let template = String(localized: "Delete \"%@\"?")
            return String(format: template, first.name)
        }
        let count = selectedFiles.count
        if count == 1 {
            let template = String(localized: "Delete %d item?")
            return String(format: template, count)
        } else {
            let template = String(localized: "Delete %d items?")
            return String(format: template, count)
        }
    }

    var body: some View {
        ZStack {
            contentView
            if let stats = manager.transferStats {
                TransferOverlay(stats: stats)
                    .transition(.opacity)
            }
            if isShowingDeviceInfo, let device = manager.connectionState.device {
                DeviceInfoOverlay(
                    device: device,
                    selectedStorage: manager.selectedStorage,
                    onDismiss: { isShowingDeviceInfo = false }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: manager.transferProgress != nil)
        .animation(.easeInOut(duration: 0.18), value: isShowingDeviceInfo)
        .toolbar { toolbarContent }
        .onChange(of: manager.connectionState) { newState in
            if case .disconnected = newState {
                selection = []
            }
        }
        .alert("New Folder", isPresented: $isShowingNewFolderDialog) {
            TextField("Folder name", text: $newFolderName)
            Button("Cancel", role: .cancel) { newFolderName = "" }
            Button("Create") {
                if !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty {
                    manager.createFolder(named: newFolderName.trimmingCharacters(in: .whitespaces))
                }
                newFolderName = ""
            }
        } message: {
            Text("Enter a name for the new folder.")
        }
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                manager.deleteFiles(selectedFiles)
                selection = []
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private var contentView: some View {
        Group {
            if #available(macOS 13.0, *) {
                NavigationSplitView {
                    SidebarView(manager: manager, selectedStorage: $manager.selectedStorage)
                        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
                } detail: {
                    VStack(spacing: 0) {
                        // Path bar
                        if manager.connectionState.isConnected {
                            pathBar
                        }

                        // File list
                        FileListView(
                            manager: manager,
                            selection: $selection,
                            onDoubleClick: { file in
                                if file.isDirectory { manager.navigate(to: file) }
                            }
                        )

                        // Status / transfer bar
                        statusBar
                    }
                }
            } else {
                VStack(spacing: 0) {
                    SidebarView(manager: manager, selectedStorage: $manager.selectedStorage)
                    if manager.connectionState.isConnected {
                        pathBar
                    }
                    FileListView(
                        manager: manager,
                        selection: $selection,
                        onDoubleClick: { file in
                            if file.isDirectory { manager.navigate(to: file) }
                        }
                    )
                    statusBar
                }
            }
        }
    }

    // MARK: – Path Bar
    private var pathBar: some View {
        HStack(spacing: 6) {
            Button {
                manager.navigateBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(!manager.canGoBack)

            PathBarView(navigationStack: manager.navigationStack) { index in
                manager.navigate(toIndex: index)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Group {
                if #available(macOS 13.0, *) {
                    Color.clear.background(.bar)
                } else {
                    Color(nsColor: .windowBackgroundColor)
                }
            }
        )
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: – Status Bar
    private var statusBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
        .background(
            Group {
                if #available(macOS 13.0, *) {
                    Color.clear.background(.bar)
                } else {
                    Color(nsColor: .windowBackgroundColor)
                }
            }
        )
    }

    private var statusText: String {
        if manager.transferStats != nil {
            return String(localized: "Transferring…")
        }
        if manager.isLoading { return String(localized: "Loading…") }
        if case let .error(message) = manager.connectionState { return message }

        if !selection.isEmpty {
            let count = selection.count
            if count == 1 {
                let template = String(localized: "%d item selected")
                return String(format: template, count)
            } else {
                let template = String(localized: "%d items selected")
                return String(format: template, count)
            }
        }

        let count = manager.sortedFiles.count
        if count == 1 {
            let template = String(localized: "%d item")
            return String(format: template, count)
        } else {
            let template = String(localized: "%d items")
            return String(format: template, count)
        }
    }

    // MARK: – Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Left: connection button
        ToolbarItemGroup(placement: .navigation) {
            if manager.connectionState.isConnected {
                Button {
                    manager.disconnect()
                    manager.selectedStorage = nil
                } label: {
                    Label("Disconnect", systemImage: "cable.connector.slash")
                }
                .help("Disconnect Device")
            } else {
                Button {
                    manager.connectDevice()
                } label: {
                    Label("Connect Device", systemImage: "cable.connector")
                }
                .help(String(localized: "Connect Device"))
            }
        }

        // Right: file actions
        ToolbarItemGroup(placement: .primaryAction) {
            // Import
            Button {
                let panel = NSOpenPanel()
                panel.canChooseFiles = true
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = true
                panel.prompt = String(localized: "Import")
                if panel.runModal() == .OK {
                    manager.upload(sourceURLs: panel.urls)
                }
            } label: {
                Label(String(localized: "Import"), systemImage: "iphone.and.arrow.forward.inward")
            }
            .help(String(localized: "Import files from Mac to device"))
            .disabled(!manager.connectionState.isConnected)
            
            // Export
            Button {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.prompt = String(localized: "Export Here")
                if panel.runModal() == .OK, let url = panel.url {
                    manager.download(files: selectedFiles, destinationURL: url)
                }
            } label: {
                Label(String(localized: "Export"), systemImage: "iphone.and.arrow.forward.outward")
            }
            .help(String(localized: "Export selected files to Mac"))
            .disabled(selectedFiles.isEmpty || !manager.connectionState.isConnected)

            Spacer(minLength: 12)

            // New Folder
            Button {
                isShowingNewFolderDialog = true
            } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
            }
            .help(String(localized: "Create new folder"))
            .disabled(!manager.connectionState.isConnected)

            // Delete
            Button {
                isShowingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .help(String(localized: "Delete selected items"))
            .disabled(selectedFiles.isEmpty || !manager.connectionState.isConnected)

            Spacer(minLength: 12)

            // Device Info
            Button {
                isShowingDeviceInfo = true
            } label: {
                Label(String(localized: "Device Info"), systemImage: "info.circle")
            }
            .help(String(localized: "Show device information"))
            .disabled(!manager.connectionState.isConnected)
        }
    }
}

// MARK: – Device Info Overlay
private struct DeviceInfoOverlay: View {
    let device: MTPDevice
    let selectedStorage: MTPStorage?
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "smartphone")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Device Information")
                        .font(.system(size: 15, weight: .semibold))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()
                    .padding(.horizontal, 20)

                // Info rows
                VStack(alignment: .leading, spacing: 0) {
                    InfoRow(label: String(localized: "Manufacturer"), value: device.manufacturer.isEmpty ? "-" : device.manufacturer)
                    InfoRow(label: String(localized: "Device Model"), value: device.name)
                    InfoRow(label: String(localized: "Protocol"), value: device.usbLinkDescription)
                    if let storage = selectedStorage {
                        InfoRow(label: String(localized: "Storage"), value: storage.name)
                        InfoRow(label: String(localized: "Free Space"), value: storage.displayFreeSpace)
                        InfoRow(label: String(localized: "Total Space"), value: storage.displayTotalSpace)
                    }
                }
                .padding(.vertical, 6)

                Divider()
                    .padding(.horizontal, 20)

                // Footer button
                HStack {
                    Spacer()
                    Button(String(localized: "Close")) {
                        onDismiss()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .frame(width: 360)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(radius: 16, y: 4)
            )
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .trailing)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

private struct TransferOverlay: View {
    let stats: TransferStatistics

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Text(stats.currentFileName)
                    .font(.system(size: 13, weight: .medium))
                    
                ProgressView(value: stats.progressPercentage)
                    .progressViewStyle(.linear)
                    .frame(width: 360)
                
                HStack(spacing: 8) {
                    Text(stats.filesProgressString)
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text(stats.speedString)
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundStyle(.secondary)
                .frame(width: 360)

                HStack(spacing: 0) {            
                    Text("\(stats.totalSentSizeString)/\(stats.totalSizeString) - ")
                        .font(.system(size: 11))
                    Text("Remaining:", tableName: "Localizable")
                        .font(.system(size: 10, weight: .semibold))
                    Text(" \(stats.remainingTimeString)")
                        .font(.system(size: 10))
                    Spacer()
                    Text(String(format: "%.0f%%", stats.progressPercentage * 100))
                        .font(.system(size: 10, design: .monospaced))
                        .frame(alignment: .trailing)
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 360)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(radius: 12)
            )
        }
    }
}

#Preview("中文") {
    MainView()
        .environment(\.locale, Locale(identifier: "zh-Hans"))
}

#Preview("English") {
    MainView()
        .environment(\.locale, Locale(identifier: "en"))
}

#Preview("日本語") {
    MainView()
        .environment(\.locale, Locale(identifier: "ja"))
}

#Preview("Espanal") {
    MainView()
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("TransferOverlay") {
    let mockProgress30: TransferStatistics = {
        let mockData = TransferProgressData(
            fullPath: "/storage/emulated/0/DCIM/Camera/VID_20250330_123456.mp4",
            name: "VID_20250330_123456.mp4",
            elapsedTime: 45_000,        // 45 seconds
            speed: 12.5,                // 12.5 MB/s
            totalFiles: 150,
            totalDirectories: 10,
            filesSent: 45,
            filesSentProgress: 30.0,
            activeFileSize: TransferSizeInfo(total: 524_288_000, sent: 157_286_400, progress: 30.0),
            bulkFileSize: TransferSizeInfo(total: 1_073_741_824, sent: 322_122_547, progress: 30.0),
            status: "transferring"
        )
        return TransferStatistics(progressData: mockData)
    }()
    TransferOverlay(stats: mockProgress30)
}
