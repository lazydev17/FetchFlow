//
//  ContentView.swift
//  TorrentClient
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var torrentManager = TorrentManager()
    @State private var isPresentingAddSheet: Bool = false
    @State private var showInspector: Bool = false

    var body: some View {
        NavigationSplitView {
            FolderSidebar()
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            FileList(isPresentingAddSheet: $isPresentingAddSheet)
                .navigationTitle(torrentManager.activeFilter.rawValue)
                .navigationSubtitle("\(torrentManager.filteredTorrents.count) downloads")
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
    }
}
