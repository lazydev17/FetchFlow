//
//  ContentView.swift
//  TorrentClient
//
//  Main macOS interface using NavigationSplitView, native toolbar,
//  integrated inspector, drag-and-drop, and liquid glass aesthetics.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var torrentManager = TorrentManager()
    @State private var isPresentingAddSheet: Bool = false
    @State private var showInspector: Bool = true
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            FolderSidebar()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
                .navigationTitle("TorrentClient")
        } detail: {
            FileList(isPresentingAddSheet: $isPresentingAddSheet)
                .navigationTitle(torrentManager.activeFilter.rawValue)
                .navigationSubtitle("\(torrentManager.filteredTorrents.count) items")
        }
        .inspector(isPresented: $showInspector) {
            TorrentInspectorView()
                .inspectorColumnWidth(min: 270, ideal: 300, max: 400)
        }
        .searchable(text: $torrentManager.searchText, placement: .toolbar, prompt: "Search downloads...")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    isPresentingAddSheet = true
                } label: {
                    Label("Add Torrent", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("o", modifiers: .command)
                .help("Add Torrent or Magnet (⌘O)")

                Button {
                    torrentManager.stopAll()
                } label: {
                    Image(systemName: "pause.fill")
                }
                .buttonStyle(.bordered)
                .help("Pause All Transfers")

                Button {
                    SettingsWindowController.show()
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.bordered)
                .help("Settings (⌘,)")

                Button {
                    withAnimation {
                        showInspector.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .buttonStyle(.bordered)
                .help("Toggle Inspector")
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            var handled = false
            for url in urls {
                if url.pathExtension.lowercased() == "torrent" {
                    torrentManager.addTorrentFile(url)
                    handled = true
                }
            }
            return handled
        }
        .sheet(isPresented: $isPresentingAddSheet) {
            AddTorrentSheet()
                .environmentObject(torrentManager)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAddTorrentSheet)) { _ in
            isPresentingAddSheet = true
        }
        .environmentObject(torrentManager)
        .frame(minWidth: 800, minHeight: 520)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
