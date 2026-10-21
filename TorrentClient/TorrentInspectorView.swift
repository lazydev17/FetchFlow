//
//  TorrentInspectorView.swift
//  TorrentClient
//
//  Bottom inspector pane matching Free Download Manager (FDM) layout:
//  Media thumbnail preview, GENERAL / PROGRESS / FILES / CONNECTIONS tabs,
//  clean metadata grid, and close button.
//

import SwiftUI
import AppKit
import QuickLookThumbnailing

// MARK: - Inspector Tab

enum InspectorTab: String, CaseIterable, Identifiable {
    case general = "GENERAL"
    case progress = "PROGRESS"
    case files = "FILES"
    case connections = "CONNECTIONS"

    var id: String { rawValue }
}

// MARK: - Main Inspector View

struct TorrentInspectorView: View {
    @EnvironmentObject private var torrentManager: TorrentManager
    let torrent: TorrentModel
    @State private var selectedTab: InspectorTab = .general

    var body: some View {
        VStack(spacing: 0) {
            // FDM-style Header Bar with Dark Tab Pills & Close Button
            inspectorHeader

            Divider()

            // Tab Content
            Group {
                switch selectedTab {
                case .general:
                    InspectorGeneralTab(torrent: torrent)
                case .progress:
                    InspectorProgressTab(torrent: torrent)
                case .files:
                    InspectorFilesTab(torrent: torrent)
                case .connections:
                    InspectorConnectionsTab(torrent: torrent)
                }
            }
            .frame(height: 185)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header Bar
    private var inspectorHeader: some View {
        HStack(spacing: 8) {
            // Pill tabs
            HStack(spacing: 4) {
                ForEach(InspectorTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(selectedTab == tab ? Color(nsColor: .windowBackgroundColor) : Color.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                selectedTab == tab
                                    ? Color(nsColor: .labelColor).opacity(0.85)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Close 'X' Button on top right
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    torrentManager.selectedInfoHash = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close Details")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

// MARK: - General Tab (FDM Layout)

struct InspectorGeneralTab: View {
    let torrent: TorrentModel
    @EnvironmentObject private var torrentManager: TorrentManager
    @State private var hasCopiedPath = false
    @State private var hasCopiedMagnet = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Media / Video Thumbnail Preview
            MediaThumbnailView(torrent: torrent)
                .frame(width: 170, height: 110)

            // Details metadata column
            VStack(alignment: .leading, spacing: 6) {
                // Large Torrent Title
                Text(torrent.name)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                // Save Path with Copy & Finder actions
                HStack(spacing: 6) {
                    Text(torrent.savePath)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(torrent.savePath, forType: .string)
                        withAnimation { hasCopiedPath = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { hasCopiedPath = false }
                        }
                    } label: {
                        Image(systemName: hasCopiedPath ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundStyle(hasCopiedPath ? Color.green : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(hasCopiedPath ? "Copied!" : "Copy Path")

                    Button {
                        torrentManager.openInFinder(torrent.infoHash)
                    } label: {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")
                }

                // Transfer & Date Stats
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Text("Downloaded:")
                            .foregroundStyle(.secondary)
                        Text(torrent.formattedTotalDownloaded)
                            .fontWeight(.medium)
                    }

                    HStack(spacing: 4) {
                        Text("Uploaded:")
                            .foregroundStyle(.secondary)
                        Text("\(torrent.formattedTotalUploaded) (ratio: \(torrent.ratioDescription))")
                            .fontWeight(.medium)
                    }

                    HStack(spacing: 4) {
                        Text("Added at:")
                            .foregroundStyle(.secondary)
                        Text(torrent.fullDateAdded)
                            .fontWeight(.medium)
                    }
                }
                .font(.system(size: 11.5))

                // Priority
                HStack(spacing: 4) {
                    Text("Priority:")
                        .foregroundStyle(.secondary)

                    Picker("", selection: Binding(
                        get: { torrent.priorityValue },
                        set: { torrentManager.setPriority($0, for: torrent.infoHash) }
                    )) {
                        ForEach(TorrentPriority.allCases) { priority in
                            Text(priority.rawValue).tag(priority)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .fixedSize()
                }
                .font(.system(size: 11.5))

                // Magnet File Link
                HStack(alignment: .center, spacing: 6) {
                    Text("File:")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11.5))

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(torrent.magnetURI, forType: .string)
                        withAnimation { hasCopiedMagnet = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { hasCopiedMagnet = false }
                        }
                    } label: {
                        Text(torrent.magnetURI)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.accentColor)
                            .underline()
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .buttonStyle(.plain)
                    .help(hasCopiedMagnet ? "Copied Magnet Link!" : "Click to copy Magnet Link")

                    if hasCopiedMagnet {
                        Text("Copied!")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.green)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Progress Tab

struct InspectorProgressTab: View {
    let torrent: TorrentModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main progress bar & percentage
            HStack(spacing: 12) {
                ProgressView(value: torrent.progress)
                    .tint(torrent.state.tintColor)

                Text(torrent.formattedProgress)
                    .font(.system(size: 14, weight: .bold).monospacedDigit())
                    .foregroundStyle(torrent.state.tintColor)
                    .frame(width: 55, alignment: .trailing)
            }

            // Metrics Grid
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow {
                    Text("Status:")
                        .foregroundStyle(.secondary)
                    Text(torrent.state.rawValue)
                        .fontWeight(.medium)

                    Text("Download Speed:")
                        .foregroundStyle(.secondary)
                    Text(torrent.downloadRate > 0 ? torrent.formattedDownloadRate : "0 B/s")
                        .fontWeight(.medium)
                        .monospacedDigit()
                }

                GridRow {
                    Text("Total Size:")
                        .foregroundStyle(.secondary)
                    Text(torrent.formattedTotalSize)
                        .fontWeight(.medium)

                    Text("Upload Speed:")
                        .foregroundStyle(.secondary)
                    Text(torrent.uploadRate > 0 ? torrent.formattedUploadRate : "0 B/s")
                        .fontWeight(.medium)
                        .monospacedDigit()
                }

                GridRow {
                    Text("Downloaded:")
                        .foregroundStyle(.secondary)
                    Text("\(torrent.formattedTotalDownloaded) of \(torrent.formattedTotalSize)")
                        .fontWeight(.medium)

                    Text("Time Remaining:")
                        .foregroundStyle(.secondary)
                    Text(torrent.etaDescription)
                        .fontWeight(.medium)
                }
            }
            .font(.system(size: 12))

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Files Tab

struct InspectorFilesTab: View {
    let torrent: TorrentModel
    @EnvironmentObject private var torrentManager: TorrentManager

    var body: some View {
        if torrent.files.isEmpty {
            ContentUnavailableView {
                Label("Fetching Metadata", systemImage: "antenna.radiowaves.left.and.right")
            } description: {
                Text("Waiting for file list from swarm peers…")
            }
        } else {
            VStack(spacing: 0) {
                // Bulk action toolbar
                HStack(spacing: 8) {
                    Text("\(torrent.files.count) files · \(torrent.formattedTotalSize)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Select All") {
                        torrentManager.setAllFilesIncluded(infoHash: torrent.infoHash, included: true)
                    }
                    .controlSize(.mini)

                    Button("Deselect All") {
                        torrentManager.setAllFilesIncluded(infoHash: torrent.infoHash, included: false)
                    }
                    .controlSize(.mini)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))

                Divider()

                // File list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(torrent.files) { file in
                            HStack(spacing: 8) {
                                Toggle("", isOn: Binding(
                                    get: { file.isIncluded },
                                    set: { _ in torrentManager.toggleFileIncluded(infoHash: torrent.infoHash, fileIndex: file.index) }
                                ))
                                .toggleStyle(.checkbox)
                                .labelsHidden()

                                Image(systemName: fileIcon(for: file.fileName))
                                    .font(.system(size: 13))
                                    .foregroundStyle(fileIconColor(for: file.fileName))
                                    .frame(width: 16)

                                Text(file.fileName)
                                    .font(.system(size: 12))
                                    .foregroundStyle(file.isIncluded ? .primary : .secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Spacer()

                                if file.isIncluded {
                                    ProgressView(value: file.progress)
                                        .tint(file.progress >= 1.0 ? .green : Color.accentColor)
                                        .frame(width: 65)

                                    Text(String(format: "%.0f%%", file.progress * 100))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 32, alignment: .trailing)
                                } else {
                                    Text("Skipped")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 101, alignment: .trailing)
                                }

                                Text(file.formattedSize)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60, alignment: .trailing)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)

                            Divider()
                                .opacity(0.4)
                                .padding(.leading, 38)
                        }
                    }
                }
            }
        }
    }

    private func fileIcon(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mkv", "avi", "mov", "webm", "m4v": return "film"
        case "mp3", "flac", "wav", "aac", "m4a", "ogg": return "music.note"
        case "zip", "tar", "gz", "rar", "7z", "bz2": return "doc.zipper"
        case "iso", "img", "dmg": return "opticaldisc"
        case "pdf", "txt", "nfo", "srt", "sub": return "doc.text"
        default: return "doc"
        }
    }

    private func fileIconColor(for filename: String) -> Color {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mkv", "avi", "mov", "webm", "m4v": return .purple
        case "mp3", "flac", "wav", "aac", "m4a", "ogg": return .pink
        case "zip", "tar", "gz", "rar", "7z", "bz2": return .orange
        case "iso", "img", "dmg": return .cyan
        case "pdf", "txt", "nfo", "srt", "sub": return .blue
        default: return .secondary
        }
    }
}

// MARK: - Connections Tab

struct InspectorConnectionsTab: View {
    let torrent: TorrentModel

    var body: some View {
        HStack(spacing: 16) {
            // Seeds card
            VStack(alignment: .leading, spacing: 6) {
                Text("SEEDS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Text("\(torrent.numSeeds)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.green)

                Text("Active connected seeds")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4), in: RoundedRectangle(cornerRadius: 8))

            // Peers card
            VStack(alignment: .leading, spacing: 6) {
                Text("PEERS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Text("\(torrent.numPeers)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentColor)

                Text("Active connected peers")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4), in: RoundedRectangle(cornerRadius: 8))

            // Swarm Health & Status card
            VStack(alignment: .leading, spacing: 6) {
                Text("SWARM HEALTH")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                HStack(spacing: 6) {
                    Circle()
                        .fill(torrent.numSeeds > 0 || torrent.numPeers > 0 ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)

                    Text(torrent.numSeeds > 0 || torrent.numPeers > 0 ? "Healthy" : "Searching")
                        .font(.system(size: 13, weight: .semibold))
                }

                if let err = torrent.error {
                    Text(err)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.red)
                        .lineLimit(2)
                } else {
                    Text("Connected to BitTorrent DHT & trackers")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Media Thumbnail Preview (QuickLook / Artwork)

struct MediaThumbnailView: View {
    let torrent: TorrentModel
    @State private var thumbnailImage: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.85))

            if let image = thumbnailImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                VStack(spacing: 6) {
                    Image(systemName: mediaIconName)
                        .font(.system(size: 26))
                        .foregroundStyle(.white.opacity(0.8))

                    Text(mediaExtension.uppercased())
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .tracking(0.5)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .onAppear { loadThumbnail() }
        .onChange(of: torrent.savePath) { loadThumbnail() }
        .onChange(of: torrent.files) { loadThumbnail() }
    }

    private var mediaExtension: String {
        if let first = torrent.files.first(where: {
            let ext = ($0.fileName as NSString).pathExtension.lowercased()
            return ["mp4", "mkv", "avi", "mov", "webm", "m4v", "mp3", "flac"].contains(ext)
        }) {
            return (first.fileName as NSString).pathExtension
        }
        if let first = torrent.files.first {
            return (first.fileName as NSString).pathExtension
        }
        let ext = (torrent.name as NSString).pathExtension
        return ext.isEmpty ? "MKV" : ext
    }

    private var mediaIconName: String {
        let ext = mediaExtension.lowercased()
        switch ext {
        case "mp4", "mkv", "avi", "mov", "webm", "m4v": return "film"
        case "mp3", "flac", "wav", "aac", "m4a": return "waveform"
        case "zip", "tar", "gz", "rar", "7z": return "doc.zipper"
        case "iso", "img", "dmg": return "opticaldisc"
        default: return "play.rectangle.fill"
        }
    }

    private func loadThumbnail() {
        let potentialUrls = [
            URL(fileURLWithPath: torrent.savePath).appendingPathComponent(torrent.name),
            URL(fileURLWithPath: torrent.savePath)
        ] + torrent.files.map { URL(fileURLWithPath: torrent.savePath).appendingPathComponent($0.path) }

        guard let existingUrl = potentialUrls.first(where: {
            var isDir: ObjCBool = false
            return FileManager.default.fileExists(atPath: $0.path, isDirectory: &isDir) && !isDir.boolValue
        }) ?? potentialUrls.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            return
        }

        let size = CGSize(width: 340, height: 220)
        let request = QLThumbnailGenerator.Request(fileAt: existingUrl, size: size, scale: 2.0, representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { rep, _ in
            if let nsImg = rep?.nsImage {
                DispatchQueue.main.async {
                    self.thumbnailImage = nsImg
                }
            }
        }
    }
}
