import SwiftUI

struct FileList: View {
    @EnvironmentObject private var torrentManager: TorrentManager
    @Binding var isPresentingAddSheet: Bool
    
    @State private var expandedTorrents: Set<String> = []
    @State private var torrentToDelete: TorrentModel? = nil
    @State private var showingDeleteConfirmation: Bool = false
    
    var body: some View {
        let items = torrentManager.filteredTorrents
        
        Group {
            if items.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(items) { torrent in
                            TorrentCard(
                                torrent: torrent,
                                isExpanded: expandedTorrents.contains(torrent.infoHash),
                                onToggleExpand: {
                                    if expandedTorrents.contains(torrent.infoHash) {
                                        expandedTorrents.remove(torrent.infoHash)
                                    } else {
                                        expandedTorrents.insert(torrent.infoHash)
                                    }
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
                                },
                                onToggleFile: { fileIndex in
                                    torrentManager.toggleFileIncluded(infoHash: torrent.infoHash, fileIndex: fileIndex)
                                }
                            )
                        }
                    }
                    .padding(16)
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
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: torrentManager.activeFilter.iconName)
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.6))
            
            VStack(spacing: 4) {
                Text(emptyTitle)
                    .font(.title2)
                    .fontWeight(.medium)
                Text(emptyDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Button {
                isPresentingAddSheet = true
            } label: {
                Label("Add Torrent", systemImage: "plus")
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)
            .help("Add Torrent (⌘O)")
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        case .all: return "Add a magnet link or .torrent file to begin."
        case .downloading: return "All your torrents have finished or are paused."
        case .completed: return "Torrents you finish downloading will appear here."
        case .paused: return "Paused torrents will appear here."
        case .active: return "No torrents are currently sending or receiving data."
        }
    }
}

// MARK: - Torrent Card
private struct TorrentCard: View {
    let torrent: TorrentModel
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onTogglePause: () -> Void
    let onOpenInFinder: () -> Void
    let onDelete: () -> Void
    let onToggleFile: (Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: torrent.state.iconName)
                    .font(.system(size: 18))
                    .foregroundStyle(stateColor)
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(torrent.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(torrent.state.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(stateColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(stateColor.opacity(0.15))
                            .cornerRadius(4)
                        
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
                
                // Action Buttons
                HStack(spacing: 6) {
                    Button(action: onTogglePause) {
                        Image(systemName: torrent.state == .paused ? "play.fill" : "pause.fill")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .help(torrent.state == .paused ? "Resume" : "Pause")
                    .accessibilityLabel(torrent.state == .paused ? "Resume" : "Pause")
                    
                    Button(action: onOpenInFinder) {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .help("Show in Finder")
                    .accessibilityLabel("Show in Finder")
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.bordered)
                    .help("Delete")
                    .accessibilityLabel("Delete")
                    
                    if !torrent.files.isEmpty {
                        Button(action: onToggleExpand) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.bordered)
                        .help("Show Files")
                        .accessibilityLabel("Show Files")
                    }
                }
            }
            
            // Progress Bar
            ProgressView(value: torrent.progress)
                .progressViewStyle(.linear)
                .tint(stateColor)
            
            // Detail Stats Footer
            HStack {
                Text("\(torrent.formattedTotalDownloaded) of \(torrent.formattedTotalSize) (\(torrent.formattedProgress))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if torrent.state == .downloading {
                    HStack(spacing: 12) {
                        Text("↓ \(torrent.formattedDownloadRate)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                        
                        Text("↑ \(torrent.formattedUploadRate)")
                            .font(.caption)
                            .fontWeight(.medium)
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
            
            // Expanded Files Subview
            if isExpanded && !torrent.files.isEmpty {
                Divider()
                    .padding(.top, 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("FILES (\(torrent.files.count))")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    
                    ForEach(torrent.files) { file in
                        HStack(spacing: 8) {
                            Button {
                                onToggleFile(file.index)
                            } label: {
                                Image(systemName: file.isIncluded ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(file.isIncluded ? Color.accentColor : Color.secondary)
                            }
                            .buttonStyle(.plain)
                            
                            Image(systemName: fileIconName(for: file.fileName))
                                .foregroundStyle(.secondary)
                                .font(.system(size: 12))
                            
                            Text(file.fileName)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                            
                            Text(file.formattedSize)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
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
    
    private func fileIconName(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mkv", "avi", "mov", "webm": return "film"
        case "mp3", "flac", "wav", "aac": return "music.note"
        case "zip", "tar", "gz", "rar", "7z": return "doc.zipper"
        case "iso", "img", "dmg": return "opticaldisc"
        case "pdf", "txt", "nfo": return "doc.text"
        default: return "doc"
        }
    }
}
