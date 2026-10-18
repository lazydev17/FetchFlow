//
//  FileList.swift
//  TorrentClient
//
//  Main download transfer list with modern macOS card styling,
//  context menus, live progress bars, and selection support.
//

import SwiftUI
import AppKit

struct FileList: View {
    @EnvironmentObject private var torrentManager: TorrentManager
    @Binding var isPresentingAddSheet: Bool

    @State private var torrentToDelete: TorrentModel? = nil
    @State private var showingDeleteConfirmation: Bool = false

    var body: some View {
        let items = torrentManager.filteredTorrents

        Group {
            if items.isEmpty {
                if !torrentManager.searchText.isEmpty {
                    ContentUnavailableView.search(text: torrentManager.searchText)
                } else {
                    ContentUnavailableView {
                        Label(emptyTitle, systemImage: torrentManager.activeFilter.iconName)
                    } description: {
                        Text(emptyDescription)
                    } actions: {
                        Button {
                            isPresentingAddSheet = true
                        } label: {
                            Label("Add Torrent", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(items) { torrent in
                            TorrentCard(
                                torrent: torrent,
                                isSelected: torrentManager.selectedInfoHash == torrent.infoHash,
                                onSelect: {
                                    torrentManager.selectedInfoHash = torrent.infoHash
                                },
                                onTogglePause: {
                                    if torrent.state == .paused {
                                        torrentManager.resumeTorrent(torrent.infoHash)
                                    } else {
                                        torrentManager.pauseTorrent(torrent.infoHash)
                                    }
                                },
                                onOpenInFinder: {
                                    torrentManager.openInFinder(torrent.infoHash)
                                },
                                onDelete: {
                                    torrentToDelete = torrent
                                    showingDeleteConfirmation = true
                                }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                torrentManager.selectedInfoHash = torrent.infoHash
                            }
                            .contextMenu {
                                Button(torrent.state == .paused ? "Resume" : "Pause") {
                                    if torrent.state == .paused {
                                        torrentManager.resumeTorrent(torrent.infoHash)
                                    } else {
                                        torrentManager.pauseTorrent(torrent.infoHash)
                                    }
                                }

                                Button("Show in Finder") {
                                    torrentManager.openInFinder(torrent.infoHash)
                                }

                                Divider()

                                Button("Copy Info Hash") {
                                    let pb = NSPasteboard.general
                                    pb.clearContents()
                                    pb.setString(torrent.infoHash, forType: .string)
                                }

                                Divider()

                                Button("Delete...", role: .destructive) {
                                    torrentToDelete = torrent
                                    showingDeleteConfirmation = true
                                }
                            }
                        }
                    }
                    .padding(14)
                }
            }
        }
        .confirmationDialog(
            "Remove Torrent",
            isPresented: $showingDeleteConfirmation,
            presenting: torrentToDelete
        ) { torrent in
            Button("Remove from Client", role: .none) {
                torrentManager.removeTorrent(torrent.infoHash, deleteFiles: false)
            }
            Button("Remove and Delete Files", role: .destructive) {
                torrentManager.removeTorrent(torrent.infoHash, deleteFiles: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: { torrent in
            Text("Are you sure you want to remove '\(torrent.name)'?")
        }
    }

    private var emptyTitle: String {
        switch torrentManager.activeFilter {
        case .all: return "No Downloads Yet"
        case .downloading: return "No Active Downloads"
        case .completed: return "No Completed Downloads"
        case .paused: return "No Paused Downloads"
        case .active: return "No Active Transfers"
        }
    }

    private var emptyDescription: String {
        switch torrentManager.activeFilter {
        case .all: return "Add a magnet link or .torrent file to begin downloading."
        case .downloading: return "All your torrents have finished or are paused."
        case .completed: return "Completed torrents will appear here."
        case .paused: return "Paused downloads will appear here."
        case .active: return "No torrents are currently sending or receiving data."
        }
    }
}

// MARK: - Modern macOS Torrent Card

private struct TorrentCard: View {
    let torrent: TorrentModel
    let isSelected: Bool
    let onSelect: () -> Void
    let onTogglePause: () -> Void
    let onOpenInFinder: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: torrent.state.iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(stateColor)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(torrent.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(torrent.state.rawValue)
                            .font(.caption)
                            .bold()
                            .foregroundStyle(stateColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(stateColor.opacity(0.15), in: Capsule())

                        Text(torrent.formattedTotalSize)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if torrent.numPeers > 0 || torrent.numSeeds > 0 {
                            Text("• \(torrent.numSeeds) seeds, \(torrent.numPeers) peers")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Row Actions
                HStack(spacing: 4) {
                    Button(action: onTogglePause) {
                        Image(systemName: torrent.state == .paused ? "play.fill" : "pause.fill")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(torrent.state == .paused ? "Resume" : "Pause")

                    Button(action: onOpenInFinder) {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Show in Finder")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Delete")
                }
            }

            // Smooth Progress Bar
            ProgressView(value: torrent.progress)
                .progressViewStyle(.linear)
                .tint(stateColor)

            // Transfer Stats Footer
            HStack {
                Text("\(torrent.formattedTotalDownloaded) of \(torrent.formattedTotalSize) (\(torrent.formattedProgress))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if torrent.state == .downloading {
                    HStack(spacing: 12) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down")
                                .font(.caption2)
                            Text(torrent.formattedDownloadRate)
                        }
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.blue)

                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up")
                                .font(.caption2)
                            Text(torrent.formattedUploadRate)
                        }
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.green)

                        Text(torrent.etaDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let error = torrent.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor).opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
        )
    }

    private var stateColor: Color {
        switch torrent.state {
        case .downloading: return .blue
        case .finished, .seeding: return .green
        case .paused: return .orange
        case .checkingFiles: return .indigo
        case .downloadingMetadata: return .purple
        case .error: return .red
        }
    }
}
