import SwiftUI

@main
struct SwiftMTPApp: App {
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
        }
        //.defaultSize(width: 900, height: 600)
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
