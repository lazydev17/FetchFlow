//
//  TorrentInspectorView.swift
//  TorrentClient
//
//  Native macOS bottom inspector pane showing selected download metadata,
//  transfer rates, swarm health, storage location, and file tree.
//

import SwiftUI
import AppKit

struct TorrentInspectorView: View {
    @EnvironmentObject private var torrentManager: TorrentManager
    let torrent: TorrentModel
    @State private var selectedTab: Int = 0 // 0 = General, 1 = Files
    @State private var fileSearchText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            Group {
                if selectedTab == 0 {
                    generalTab
                } else {
                    filesTab
                }
            }
            .frame(height: 190)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 12) {
            Image(systemName: torrent.state.iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(stateColor(for: torrent.state))

            Text(torrent.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)

            Text(torrent.state.rawValue.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(stateColor(for: torrent.state))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(stateColor(for: torrent.state).opacity(0.12), in: Capsule())

            Spacer()

            Picker("", selection: $selectedTab) {
                Text("General").tag(0)
                Text("Files (\(torrent.files.count))").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 170)

            Divider()
                .frame(height: 16)

            Button {
                torrent.state == .paused
                    ? torrentManager.resumeTorrent(torrent.infoHash)
                    : torrentManager.pauseTorrent(torrent.infoHash)
            } label: {
                Image(systemName: torrent.state == .paused ? "play.fill" : "pause.fill")
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .help(torrent.state == .paused ? "Resume" : "Pause")

            Button {
                torrentManager.openInFinder(torrent.infoHash)
            } label: {
                Image(systemName: "folder")
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .help("Show in Finder")

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    torrentManager.selectedInfoHash = nil
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .help("Close Details Pane")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - General Tab
    private var generalTab: some View {
        HStack(alignment: .top, spacing: 20) {
            // Column 1: Transfer
            VStack(alignment: .leading, spacing: 10) {
                Text("TRANSFER")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        ProgressView(value: torrent.progress)
                            .tint(stateColor(for: torrent.state))
                        Text(torrent.formattedProgress)
                            .font(.system(.caption2, design: .monospaced).weight(.semibold))
                            .monospacedDigit()
                    }
                    Text("\(torrent.formattedTotalDownloaded) of \(torrent.formattedTotalSize)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 14) {
                    Label(torrent.formattedDownloadRate, systemImage: "arrow.down")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .monospacedDigit()

                    Label(torrent.formattedUploadRate, systemImage: "arrow.up")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .monospacedDigit()
                }

                if torrent.state == .downloading {
                    Text("ETA: \(torrent.etaDescription)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Column 2: Swarm
            VStack(alignment: .leading, spacing: 10) {
                Text("SWARM")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Seeds")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(torrent.numSeeds)")
                            .font(.system(.callout, design: .rounded).weight(.semibold))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Peers")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(torrent.numPeers)")
                            .font(.system(.callout, design: .rounded).weight(.semibold))
                    }
                }

                if let err = torrent.error {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
            .frame(width: 140, alignment: .leading)

            Divider()

            // Column 3: Storage & Hash
            VStack(alignment: .leading, spacing: 10) {
                Text("STORAGE & HASH")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Save Location:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(torrent.savePath)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Info Hash:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text(torrent.infoHash)
                            .font(.system(size: 10, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(torrent.infoHash, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .help("Copy Hash")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Files Tab
    private var filesTab: some View {
        Group {
            if torrent.files.isEmpty {
                VStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Fetching file metadata from peers...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(torrent.files) { file in
                        HStack(spacing: 8) {
                            Button {
                                torrentManager.toggleFileIncluded(infoHash: torrent.infoHash, fileIndex: file.index)
                            } label: {
                                Image(systemName: file.isIncluded ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(file.isIncluded ? Color.accentColor : Color.secondary)
                            }
                            .buttonStyle(.plain)

                            Image(systemName: fileIcon(for: file.fileName))
                                .foregroundStyle(.secondary)
                                .font(.system(size: 12))

                            Text(file.fileName)
                                .font(.system(size: 12))
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Text(file.formattedSize)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            if file.progress > 0 {
                                Text(String(format: "%.0f%%", file.progress * 100))
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 38, alignment: .trailing)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private func stateColor(for state: TorrentState) -> Color {
        switch state {
        case .downloading: .blue
        case .finished, .seeding: .green
        case .paused: .orange
        case .checkingFiles: .indigo
        case .downloadingMetadata: .purple
        case .error: .red
        }
    }

    private func fileIcon(for filename: String) -> String {
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
