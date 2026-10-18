import SwiftUI
import AppKit

struct FileList: View {
    @EnvironmentObject private var torrentManager: TorrentManager
    @Binding var isPresentingAddSheet: Bool
    @State private var torrentToDelete: TorrentModel?
    @State private var showingDeleteConfirmation = false

    private var items: [TorrentModel] { torrentManager.filteredTorrents }

    var body: some View {
        VStack(spacing: 0) {
            if items.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: Binding(
                    get: { torrentManager.selectedInfoHash },
                    set: { torrentManager.selectedInfoHash = $0 }
                )) {
                    ForEach(items) { torrent in
                        TorrentRow(torrent: torrent)
                            .tag(torrent.infoHash)
                            .contextMenu { contextMenu(for: torrent) }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    torrentToDelete = torrent
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    torrent.state == .paused
                                        ? torrentManager.resumeTorrent(torrent.infoHash)
                                        : torrentManager.pauseTorrent(torrent.infoHash)
                                } label: {
                                    Label(
                                        torrent.state == .paused ? "Resume" : "Pause",
                                        systemImage: torrent.state == .paused ? "play.fill" : "pause.fill"
                                    )
                                }
                                .tint(torrent.state == .paused ? .green : .orange)
                            }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .alternatingRowBackgrounds(.enabled)
            }

            if let selectedTorrent = torrentManager.selectedTorrent {
                Divider()
                TorrentInspectorView(torrent: selectedTorrent)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .confirmationDialog("Remove Torrent", isPresented: $showingDeleteConfirmation, presenting: torrentToDelete) { torrent in
            Button("Remove from Client") { torrentManager.removeTorrent(torrent.infoHash, deleteFiles: false) }
            Button("Remove and Delete Files", role: .destructive) { torrentManager.removeTorrent(torrent.infoHash, deleteFiles: true) }
            Button("Cancel", role: .cancel) {}
        } message: { torrent in
            Text("Are you sure you want to remove '\(torrent.name)'?")
        }
    }

    @ViewBuilder private var emptyState: some View {
        if !torrentManager.searchText.isEmpty {
            ContentUnavailableView.search
        } else {
            ContentUnavailableView {
                Label(emptyTitle, systemImage: torrentManager.activeFilter.iconName)
            } description: {
                Text(emptyDescription)
            } actions: {
                Button("Add Download", systemImage: "plus") { isPresentingAddSheet = true }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("o", modifiers: .command)
            }
        }
    }

    @ViewBuilder private func contextMenu(for torrent: TorrentModel) -> some View {
        Button(torrent.state == .paused ? "Resume" : "Pause") {
            torrent.state == .paused ? torrentManager.resumeTorrent(torrent.infoHash) : torrentManager.pauseTorrent(torrent.infoHash)
        }
        Button("Show in Finder") { torrentManager.openInFinder(torrent.infoHash) }
        Divider()
        Button("Copy Info Hash") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(torrent.infoHash, forType: .string)
        }
        Divider()
        Button("Remove…", role: .destructive) { torrentToDelete = torrent; showingDeleteConfirmation = true }
    }

    private var emptyTitle: String {
        switch torrentManager.activeFilter {
        case .all: "No Downloads Yet"
        case .downloading: "Nothing Downloading"
        case .completed: "No Completed Downloads"
        case .paused: "No Paused Downloads"
        case .active: "No Active Transfers"
        }
    }

    private var emptyDescription: String {
        switch torrentManager.activeFilter {
        case .all: "Add a magnet link or torrent file to get started."
        case .downloading: "Your downloads will appear here when they start."
        case .completed: "Completed transfers will be collected here."
        case .paused: "Paused transfers will appear here."
        case .active: "There are no transfers moving data right now."
        }
    }
}

// MARK: - Torrent Row

struct TorrentRow: View {
    let torrent: TorrentModel
    @EnvironmentObject private var torrentManager: TorrentManager

    var body: some View {
        HStack(spacing: 12) {
            // State icon
            Image(systemName: torrent.state.iconName)
                .font(.title2)
                .foregroundStyle(torrent.state.tintColor)
                .frame(width: 26)

            // Main content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(torrent.name)
                        .font(.system(.body, weight: .semibold))
                        .lineLimit(1)

                    Text(torrent.state.rawValue.uppercased())
                        .font(.system(size: 8.5, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(torrent.state.tintColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(torrent.state.tintColor.opacity(0.12), in: Capsule())
                        .overlay(Capsule().stroke(torrent.state.tintColor.opacity(0.24), lineWidth: 0.5))
                }

                ProgressView(value: torrent.progress)
                    .tint(torrent.state.tintColor)

                HStack(spacing: 14) {
                    Text("\(torrent.formattedTotalDownloaded) of \(torrent.formattedTotalSize)")

                    if torrent.state == .downloading || torrent.state == .seeding {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                            Text(torrent.formattedDownloadRate)
                        }

                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.green)
                            Text(torrent.formattedUploadRate)
                        }

                        Text(torrent.etaDescription)
                            .foregroundStyle(.secondary)
                    } else if torrent.numPeers > 0 || torrent.numSeeds > 0 {
                        Text("\(torrent.numSeeds) seeds · \(torrent.numPeers) peers")
                    }

                    if let error = torrent.error {
                        Text(error)
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }

            Spacer(minLength: 0)

            // Quick Action Buttons
            HStack(spacing: 4) {
                Button {
                    torrent.state == .paused
                        ? torrentManager.resumeTorrent(torrent.infoHash)
                        : torrentManager.pauseTorrent(torrent.infoHash)
                } label: {
                    Image(systemName: torrent.state == .paused ? "play.fill" : "pause.fill")
                        .frame(width: 16, height: 16)
                }
                .help(torrent.state == .paused ? "Resume" : "Pause")

                Button {
                    torrentManager.openInFinder(torrent.infoHash)
                } label: {
                    Image(systemName: "folder")
                        .frame(width: 16, height: 16)
                }
                .help("Show in Finder")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}
