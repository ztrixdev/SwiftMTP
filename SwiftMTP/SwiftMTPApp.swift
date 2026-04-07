import SwiftUI

@main
struct SwiftMTPApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        //.defaultSize(width: 900, height: 600)
    }
}
