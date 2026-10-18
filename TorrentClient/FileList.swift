import SwiftUI
import AppKit

struct FileList: View {
    @EnvironmentObject private var torrentManager: TorrentManager
    @Binding var isPresentingAddSheet: Bool
    @State private var torrentToDelete: TorrentModel?
    @State private var showingDeleteConfirmation = false

    private var items: [TorrentModel] { torrentManager.filteredTorrents }
    private var activeCount: Int { items.filter { $0.downloadRate > 0 || $0.uploadRate > 0 }.count }

    var body: some View {
        VStack(spacing: 0) {
            libraryHeader
            Divider()
            if items.isEmpty { emptyState }
            else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { torrent in
                            TorrentRow(
                                torrent: torrent,
                                isSelected: torrentManager.selectedInfoHash == torrent.infoHash,
                                select: { torrentManager.selectedInfoHash = torrent.infoHash },
                                togglePause: {
                                    torrent.state == .paused
                                        ? torrentManager.resumeTorrent(torrent.infoHash)
                                        : torrentManager.pauseTorrent(torrent.infoHash)
                                },
                                reveal: { torrentManager.openInFinder(torrent.infoHash) },
                                remove: { torrentToDelete = torrent; showingDeleteConfirmation = true }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { torrentManager.selectedInfoHash = torrent.infoHash }
                            .contextMenu { contextMenu(for: torrent) }
                            Divider().padding(.leading, 64)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
        .confirmationDialog("Remove Torrent", isPresented: $showingDeleteConfirmation, presenting: torrentToDelete) { torrent in
            Button("Remove from Client") { torrentManager.removeTorrent(torrent.infoHash, deleteFiles: false) }
            Button("Remove and Delete Files", role: .destructive) { torrentManager.removeTorrent(torrent.infoHash, deleteFiles: true) }
            Button("Cancel", role: .cancel) {}
        } message: { torrent in
            Text("Are you sure you want to remove ‘\(torrent.name)’?")
        }
    }

    private var libraryHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(torrentManager.activeFilter.rawValue)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(items.isEmpty ? "Your transfer library" : "\(items.count) downloads · \(activeCount) active")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { torrentManager.stopAll() } label: {
                    Label("Pause All", systemImage: "pause.fill")
                }
                .disabled(activeCount == 0)
                .help("Pause all transfers")
            }
            HStack(spacing: 18) {
                transferMetric(title: "DOWNLOADING", value: ByteCountFormatter.string(fromByteCount: torrentManager.totalDownloadRate, countStyle: .binary) + "/s", icon: "arrow.down", color: .blue)
                transferMetric(title: "UPLOADING", value: ByteCountFormatter.string(fromByteCount: torrentManager.totalUploadRate, countStyle: .binary) + "/s", icon: "arrow.up", color: .green)
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(.bar)
    }

    private func transferMetric(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
                .frame(width: 28, height: 28).background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 9, weight: .bold)).tracking(0.7).foregroundStyle(.secondary)
                Text(value).font(.system(.caption, design: .monospaced).weight(.medium)).monospacedDigit()
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
                    .buttonStyle(.borderedProminent).keyboardShortcut("o", modifiers: .command)
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
            Image(systemName: torrent.state.iconName)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(stateColor)
                .frame(width: 34, height: 34)
                .background(stateColor.opacity(0.11), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(torrent.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(torrent.state.rawValue.uppercased()).font(.system(size: 9, weight: .bold)).tracking(0.45)
                        .foregroundStyle(stateColor).padding(.horizontal, 7).padding(.vertical, 3)
                        .background(stateColor.opacity(0.11), in: Capsule())
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
                            .foregroundStyle(.blue)
                        Label(torrent.formattedUploadRate, systemImage: "arrow.up")
                            .foregroundStyle(.green)
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
        .padding(.horizontal, 12).padding(.vertical, 13)
        .background(isSelected ? Color.accentColor.opacity(0.09) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        .padding(.vertical, 3)
        .accessibilityElement(children: .contain)
    }

    private func rowButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).frame(width: 25, height: 25) }
            .buttonStyle(.borderless).controlSize(.small).help(help)
    }

    private var stateColor: Color {
        switch torrent.state {
        case .downloading: .blue
        case .finished, .seeding: .green
        case .paused: .orange
        case .checkingFiles: .indigo
        case .downloadingMetadata: .purple
        case .error: .red
        }
    }
}
