import SwiftUI

@main
struct TorrentClientApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Color.accentColor)
        }
        .defaultSize(width: 900, height: 600)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView()
            }

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

struct CheckForUpdatesView: View {
    @ObservedObject private var updaterModel = UpdaterViewModel.shared

    var body: some View {
        Button("Check for Updates…") {
            updaterModel.checkForUpdates()
        }
        .disabled(!updaterModel.canCheckForUpdates)
    }
}

extension Notification.Name {
    static let openAddTorrentSheet = Notification.Name("openAddTorrentSheet")
}
