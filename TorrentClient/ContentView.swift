//
//  ContentView.swift
//  TorrentClient
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var torrentManager = TorrentManager()
    @State private var isPresentingAddSheet = false
    @State private var showingDeleteCheckedConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            FileList(isPresentingAddSheet: $isPresentingAddSheet)
        }
        .frame(minWidth: 780, minHeight: 480)
        .searchable(text: $torrentManager.searchText, placement: .toolbar, prompt: "Search in downloads…")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                // Filter Dropdown
                Menu {
                    ForEach(TorrentFilter.allCases) { filter in
                        Button {
                            torrentManager.activeFilter = filter
                        } label: {
                            HStack {
                                Text(filter.rawValue)
                                if torrentManager.activeFilter == filter {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(torrentManager.activeFilter.rawValue)
                            .font(.system(size: 13, weight: .medium))

                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .menuIndicator(.hidden)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                // Play / Pause Button (adapts to selected checkbox state)
                Button {
                    if torrentManager.hasCheckedTorrents {
                        if torrentManager.hasActiveCheckedTorrents {
                            torrentManager.pauseChecked()
                        } else {
                            torrentManager.resumeChecked()
                        }
                    } else {
                        if torrentManager.hasActiveTorrents {
                            torrentManager.pauseAll()
                        } else {
                            torrentManager.resumeAll()
                        }
                    }
                } label: {
                    Label(
                        playPauseButtonTitle,
                        systemImage: playPauseButtonIcon
                    )
                }
                .disabled(torrentManager.hasCheckedTorrents ? false : torrentManager.torrents.isEmpty)
                .help(playPauseButtonHelp)

                // Delete Button (Shown when a checkbox is selected)
                if torrentManager.hasCheckedTorrents {
                    Button(role: .destructive) {
                        showingDeleteCheckedConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .help("Remove \(torrentManager.checkedInfoHashes.count) Selected Download(s)")
                }

                // Add Torrent Button
                Button {
                    isPresentingAddSheet = true
                } label: {
                    Label("Add Torrent", systemImage: "plus")
                }
                .keyboardShortcut("o", modifiers: .command)
                .help("Add Torrent or Magnet (⌘O)")

                // Inspector Details Toggle
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
        .confirmationDialog(
            "Remove Download\(torrentManager.checkedInfoHashes.count > 1 ? "s" : "")",
            isPresented: $showingDeleteCheckedConfirmation
        ) {
            Button("Remove from Client") {
                torrentManager.removeChecked(deleteFiles: false)
            }
            Button("Remove and Delete Files", role: .destructive) {
                torrentManager.removeChecked(deleteFiles: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove \(torrentManager.checkedInfoHashes.count) selected download\(torrentManager.checkedInfoHashes.count == 1 ? "" : "s")?")
        }
        .dropDestination(for: URL.self) { urls, _ in
            var handled = false
            for url in urls {
                let ext = url.pathExtension.lowercased()
                if ext == "torrent" {
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

    private var playPauseButtonTitle: String {
        if torrentManager.hasCheckedTorrents {
            return torrentManager.hasActiveCheckedTorrents ? "Pause" : "Resume"
        } else {
            return torrentManager.hasActiveTorrents ? "Pause All" : "Resume All"
        }
    }

    private var playPauseButtonIcon: String {
        if torrentManager.hasCheckedTorrents {
            return torrentManager.hasActiveCheckedTorrents ? "pause.fill" : "play.fill"
        } else {
            return torrentManager.hasActiveTorrents ? "pause.fill" : "play.fill"
        }
    }

    private var playPauseButtonHelp: String {
        if torrentManager.hasCheckedTorrents {
            return torrentManager.hasActiveCheckedTorrents ? "Pause Selected Download(s)" : "Resume Selected Download(s)"
        } else {
            return torrentManager.hasActiveTorrents ? "Pause All Downloads" : "Resume All Downloads"
        }
    }
}
