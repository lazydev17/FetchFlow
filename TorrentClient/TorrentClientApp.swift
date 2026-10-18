import SwiftUI

@main
struct TorrentClientApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    SettingsWindowController.show()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            CommandGroup(replacing: .newItem) {
                Button("Add Torrent or Magnet...") {
                    NotificationCenter.default.post(name: .openAddTorrentSheet, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let openAddTorrentSheet = Notification.Name("openAddTorrentSheet")
}
