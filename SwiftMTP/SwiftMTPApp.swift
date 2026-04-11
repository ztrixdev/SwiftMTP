import SwiftUI

@main
struct SwiftMTPApp: App {
    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .newItem) {
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
            Button(String(localized: "Enclosing Folder")) { navigateBackAction?() }
                .keyboardShortcut(.upArrow, modifiers: [.command])
                .disabled(canGoBack != true)
                
            Divider()
            
            Button(String(localized: "Photos")) { navigateToPathAction?("/DCIM") }
                .disabled(isConnected != true)
            Button(String(localized: "Downloads")) { navigateToPathAction?("/Download") }
                .keyboardShortcut("l", modifiers: [.command, .option])
                .disabled(isConnected != true)
            Button(String(localized: "Bluetooth")) { navigateToPathAction?("/Bluetooth") }
                .disabled(isConnected != true)
            Button(String(localized: "Screenshots")) { navigateToPathAction?("/Pictures/Screenshots") }
                .disabled(isConnected != true)
                
            Divider()
            
            Button(String(localized: "Go to Folder...")) { showFolderPromptAction?() }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(isConnected != true)
        }
    }
}

struct IsConnectedFocusedKey: FocusedValueKey { typealias Value = Bool }
struct CanGoBackFocusedKey: FocusedValueKey { typealias Value = Bool }
struct NavigateToPathActionFocusedKey: FocusedValueKey { typealias Value = (String) -> Void }
struct NavigateBackActionFocusedKey: FocusedValueKey { typealias Value = () -> Void }
struct ShowFolderPromptActionFocusedKey: FocusedValueKey { typealias Value = () -> Void }

extension FocusedValues {
    var isConnected: Bool? {
        get { self[IsConnectedFocusedKey.self] }
        set { self[IsConnectedFocusedKey.self] = newValue }
    }
    var canGoBack: Bool? {
        get { self[CanGoBackFocusedKey.self] }
        set { self[CanGoBackFocusedKey.self] = newValue }
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
}
