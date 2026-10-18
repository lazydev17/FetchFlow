//
//  TorrentInspectorView.swift
//  TorrentClient
//
//  Native macOS bottom inspector pane showing selected download metadata,
//  transfer rates, swarm health, storage location, and file tree.
//

import SwiftUI
import AppKit

// MARK: - Inspector Tab

enum InspectorTab: String, CaseIterable, Identifiable {
    case general = "General"
    case files = "Files"

    var id: String { rawValue }
}

// MARK: - Inspector View

struct TorrentInspectorView: View {
    @EnvironmentObject private var torrentManager: TorrentManager
    let torrent: TorrentModel
    @State private var selectedTab: InspectorTab = .general

    var body: some View {
        VStack(spacing: 0) {
            inspectorHeader

            Divider()

            Group {
                switch selectedTab {
                case .general:
                    InspectorGeneralTab(torrent: torrent)
                case .files:
                    InspectorFilesTab(torrent: torrent)
                }
            }
            .frame(height: 195)
        }
        .background(.bar)
    }

    // MARK: - Header Bar

    private var inspectorHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: torrent.state.iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(torrent.state.tintColor)

            Text(torrent.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)

            // State Pill
            Text(torrent.state.rawValue.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(torrent.state.tintColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(torrent.state.tintColor.opacity(0.12), in: Capsule())
                .overlay(Capsule().stroke(torrent.state.tintColor.opacity(0.25), lineWidth: 0.5))

            Spacer()

            // Segmented Tab Picker
            Picker("", selection: $selectedTab) {
                Text("General").tag(InspectorTab.general)
                Text("Files (\(torrent.files.count))").tag(InspectorTab.files)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 175)

            Divider()
                .frame(height: 16)

            // Action Buttons
            HStack(spacing: 2) {
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

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        torrentManager.selectedInfoHash = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                }
                .help("Close Inspector")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }
}

// MARK: - General Tab

struct InspectorGeneralTab: View {
    let torrent: TorrentModel
    @EnvironmentObject private var torrentManager: TorrentManager
    @State private var hasCopiedHash = false

    var body: some View {
        HStack(spacing: 10) {
            transferCard
            swarmCard
            storageCard
        }
        .padding(12)
    }

    // MARK: - Transfer Card
    private var transferCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeader(title: "Transfer", icon: "arrow.down.arrow.up", color: Color.accentColor)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    ProgressView(value: torrent.progress)
                        .tint(torrent.state.tintColor)
                    Text(torrent.formattedProgress)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                }

                Text("\(torrent.formattedTotalDownloaded) of \(torrent.formattedTotalSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                        Text(torrent.formattedDownloadRate)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.primary)
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.green)
                        Text(torrent.formattedUploadRate)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                if torrent.state == .downloading {
                    Text("ETA: \(torrent.etaDescription)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground)
    }

    // MARK: - Swarm Card
    private var swarmCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeader(title: "Swarm", icon: "person.2.fill", color: .green)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(torrent.numSeeds)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Seeds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(torrent.numPeers)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Peers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let err = torrent.error {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text(err)
                        .font(.caption)
                        .lineLimit(2)
                }
                .foregroundStyle(.red)
            } else {
                Text(torrent.state == .downloading || torrent.state == .seeding ? "Connected to swarm" : "Idle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(minWidth: 135, maxWidth: 150, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground)
    }

    // MARK: - Storage & Hash Card
    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeader(title: "Storage & Hash", icon: "externaldrive.fill", color: .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Save Location:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Text(torrent.savePath)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button {
                        torrentManager.openInFinder(torrent.infoHash)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Info Hash:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 5) {
                    Text(torrent.infoHash)
                        .font(.system(size: 9.5, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(torrent.infoHash, forType: .string)
                        withAnimation { hasCopiedHash = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { hasCopiedHash = false }
                        }
                    } label: {
                        Image(systemName: hasCopiedHash ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                            .foregroundStyle(hasCopiedHash ? Color.green : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(hasCopiedHash ? "Copied!" : "Copy Info Hash")
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground)
    }

    // MARK: - Helpers
    private func cardHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)

            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
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
                .padding(.vertical, 5)
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
