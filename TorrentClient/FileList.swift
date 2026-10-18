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
            headerBar

            if items.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(items) { torrent in
                            TorrentRow(
                                torrent: torrent,
                                isSelected: torrentManager.selectedInfoHash == torrent.infoHash,
                                select: {
                                    toggleSelection(for: torrent)
                                },
                                togglePause: {
                                    torrent.state == .paused
                                        ? torrentManager.resumeTorrent(torrent.infoHash)
                                        : torrentManager.pauseTorrent(torrent.infoHash)
                                },
                                reveal: { torrentManager.openInFinder(torrent.infoHash) },
                                remove: { torrentToDelete = torrent; showingDeleteConfirmation = true }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleSelection(for: torrent)
                            }
                            .contextMenu { contextMenu(for: torrent) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }

            if let selectedTorrent = torrentManager.selectedTorrent {
                Divider()
                TorrentInspectorView(torrent: selectedTorrent)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(.ultraThinMaterial)
        .confirmationDialog("Remove Torrent", isPresented: $showingDeleteConfirmation, presenting: torrentToDelete) { torrent in
            Button("Remove from Client") { torrentManager.removeTorrent(torrent.infoHash, deleteFiles: false) }
            Button("Remove and Delete Files", role: .destructive) { torrentManager.removeTorrent(torrent.infoHash, deleteFiles: true) }
            Button("Cancel", role: .cancel) {}
        } message: { torrent in
            Text("Are you sure you want to remove ‘\(torrent.name)’?")
        }
    }

    private var headerBar: some View {
        HStack(alignment: .center) {
            Text(torrentManager.activeFilter.rawValue)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Spacer()

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
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(torrentManager.torrents.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    private func toggleSelection(for torrent: TorrentModel) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if torrentManager.selectedInfoHash == torrent.infoHash {
                torrentManager.selectedInfoHash = nil
            } else {
                torrentManager.selectedInfoHash = torrent.infoHash
            }
        }
    }

    @ViewBuilder private var emptyState: some View {
        if !torrentManager.searchText.isEmpty {
            ContentUnavailableView.search(text: torrentManager.searchText)
        } else {
            ContentUnavailableView {
                Label(emptyTitle, systemImage: torrentManager.activeFilter.iconName)
            } description: {
                Text(emptyDescription)
            } actions: {
                Button { isPresentingAddSheet = true } label: { Label("Add Download", systemImage: "plus") }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
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

private struct TorrentRow: View {
    let torrent: TorrentModel
    let isSelected: Bool
    let select: () -> Void
    let togglePause: () -> Void
    let reveal: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            SettingsBadgeIcon(
                systemImage: torrent.state.iconName,
                gradient: SettingsBadgeIcon.gradient(for: torrent.state),
                size: 28,
                iconSize: 13
            )
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(torrent.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(torrent.state.rawValue.uppercased()).font(.system(size: 9, weight: .bold)).tracking(0.45)
                        .foregroundStyle(stateColor).padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.5), in: Capsule())
                }
                HStack(spacing: 8) {
                    ProgressView(value: torrent.progress).tint(stateColor).frame(maxWidth: .infinity)
                    Text(torrent.formattedProgress).font(.system(.caption2, design: .monospaced).weight(.medium))
                        .monospacedDigit().foregroundStyle(.secondary).frame(width: 42, alignment: .trailing)
                }
                HStack(spacing: 12) {
                    Label("\(torrent.formattedTotalDownloaded) of \(torrent.formattedTotalSize)", systemImage: "externaldrive")
                    if torrent.state == .downloading || torrent.state == .seeding {
                        Label(torrent.formattedDownloadRate, systemImage: "arrow.down")
                            .foregroundStyle(.primary)
                        Label(torrent.formattedUploadRate, systemImage: "arrow.up")
                            .foregroundStyle(.secondary)
                        Text(torrent.etaDescription)
                    } else if torrent.numPeers > 0 || torrent.numSeeds > 0 {
                        Text("\(torrent.numSeeds) seeds · \(torrent.numPeers) peers")
                    }
                    Spacer(minLength: 0)
                    if let error = torrent.error { Text(error).foregroundStyle(.red).lineLimit(1) }
                }
                .font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(.secondary).lineLimit(1)
            }
            HStack(spacing: 2) {
                rowButton(torrent.state == .paused ? "play.fill" : "pause.fill", help: torrent.state == .paused ? "Resume" : "Pause", action: togglePause)
                rowButton("folder", help: "Show in Finder", action: reveal)
                rowButton("trash", help: "Remove", action: remove)
            }
            .opacity(isSelected ? 1 : 0.65)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color(nsColor: .selectedContentBackgroundColor).opacity(0.18))
            } else {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(.regularMaterial)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(isSelected ? Color(nsColor: .separatorColor).opacity(0.7) : Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1.5)
        .accessibilityElement(children: .contain)
    }

    private func rowButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).frame(width: 24, height: 24) }
            .buttonStyle(.borderless).controlSize(.small).help(help)
    }

    private var stateColor: Color {
        switch torrent.state {
        case .downloading: .primary
        case .finished, .seeding: .green
        case .paused: .secondary
        case .checkingFiles: .secondary
        case .downloadingMetadata: .secondary
        case .error: .red
        }
    }
}
