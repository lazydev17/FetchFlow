import SwiftUI
import AppKit

@main
struct FetchFlowApp: App {
    // A single manager/session is shared by every window scene.
    @StateObject private var torrentManager = TorrentManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(torrentManager)
                .tint(Color.accentColor)
                .background(WindowConfigurator())
        }
        .defaultSize(width: 900, height: 600)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView()
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings") {
                    SettingsWindowController.show()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            CommandGroup(replacing: .newItem) {
                Button("Add Torrent or Magnet") {
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
        Button("Check for Updates") {
            updaterModel.checkForUpdates()
        }
        .disabled(!updaterModel.canCheckForUpdates)
    }
}

extension Notification.Name {
    static let openAddTorrentSheet = Notification.Name("openAddTorrentSheet")
}

// MARK: - Window Chrome Configurator

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
