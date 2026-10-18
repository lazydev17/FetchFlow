//
//  ContentView.swift
//  TorrentClient
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var torrentManager = TorrentManager()
    @State private var isPresentingAddSheet = false

    var body: some View {
        NavigationSplitView {
            FolderSidebar()
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            FileList(isPresentingAddSheet: $isPresentingAddSheet)
                .navigationTitle(torrentManager.activeFilter.rawValue)
                .navigationSubtitle(statusSubtitle)
        }
        .searchable(text: $torrentManager.searchText, placement: .toolbar, prompt: "Search downloads…")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    if torrentManager.hasActiveTorrents {
                        torrentManager.pauseAll()
                    } else {
                        torrentManager.resumeAll()
                    }
                } label: {
                    Label(
                        torrentManager.hasActiveTorrents ? "Pause All" : "Resume All",
                        systemImage: torrentManager.hasActiveTorrents ? "pause.fill" : "play.fill"
                    )
                }
                .disabled(torrentManager.torrents.isEmpty)
                .help(torrentManager.hasActiveTorrents ? "Pause All Downloads" : "Resume All Downloads")

                Button {
                    isPresentingAddSheet = true
                } label: {
                    Label("Add Torrent", systemImage: "plus")
                }
                .keyboardShortcut("o", modifiers: .command)
                .help("Add Torrent or Magnet (⌘O)")

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if torrentManager.selectedInfoHash != nil {
                            torrentManager.selectedInfoHash = nil
                        } else if let first = torrentManager.filteredTorrents.first {
                            torrentManager.selectedInfoHash = first.infoHash
                        }
                    }
                } label: {
                    Label("Details", systemImage: "info.circle")
                }
                .disabled(torrentManager.filteredTorrents.isEmpty)
                .help(torrentManager.selectedInfoHash != nil ? "Hide Inspector" : "Show Inspector")
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

    private var statusSubtitle: String {
        let count = torrentManager.filteredTorrents.count
        if count == 0 { return "" }

        let dl = torrentManager.totalDownloadRate
        let ul = torrentManager.totalUploadRate
        var parts: [String] = ["\(count) torrent\(count == 1 ? "" : "s")"]
        if dl > 0 {
            parts.append("↓ \(ByteCountFormatter.string(fromByteCount: dl, countStyle: .binary))/s")
        }
        if ul > 0 {
            parts.append("↑ \(ByteCountFormatter.string(fromByteCount: ul, countStyle: .binary))/s")
        }
        return parts.joined(separator: " — ")
    }
}
