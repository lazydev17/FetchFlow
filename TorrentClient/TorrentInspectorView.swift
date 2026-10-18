//
//  TorrentInspectorView.swift
//  TorrentClient
//
//  Native macOS right-hand inspector view showing selected download metadata,
//  swarm health, and file selection tree.
//

import SwiftUI
import AppKit

struct TorrentInspectorView: View {
    @EnvironmentObject private var torrentManager: TorrentManager
    @State private var selectedTab: Int = 0 // 0 = Info, 1 = Files
    @State private var fileSearchText: String = ""

    var body: some View {
        Group {
            if let torrent = torrentManager.selectedTorrent {
                VStack(spacing: 0) {
                    // Inspector Header
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: torrent.state.iconName)
                                .font(.title3)
                                .foregroundStyle(stateColor(for: torrent.state))

                            Text(torrent.name)
                                .font(.headline)
                                .lineLimit(2)
                        }

                        HStack(spacing: 8) {
                            Text(torrent.state.rawValue)
                                .font(.caption)
                                .bold()
                                .foregroundStyle(stateColor(for: torrent.state))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(stateColor(for: torrent.state).opacity(0.15), in: Capsule())

                            Text(torrent.formattedTotalSize)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(torrent.formattedProgress)
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }

                        ProgressView(value: torrent.progress)
                            .progressViewStyle(.linear)
                            .tint(stateColor(for: torrent.state))
                    }
                    .padding(14)
                    .background(.quaternary.opacity(0.3))

                    Divider()

                    // Tab Picker
                    Picker("Inspector View", selection: $selectedTab) {
                        Text("Details").tag(0)
                        Text("Files (\(torrent.files.count))").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)

                    Divider()

                    // Tab Content
                    if selectedTab == 0 {
                        detailsPane(torrent: torrent)
                    } else {
                        filesPane(torrent: torrent)
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "sidebar.right",
                    description: Text("Select a torrent to view transfer rates, peer statistics, and file details.")
                )
            }
        }
    }

    // MARK: - Details Pane

    private func detailsPane(torrent: TorrentModel) -> some View {
        Form {
            Section("Transfer") {
                LabeledContent("Downloaded", value: "\(torrent.formattedTotalDownloaded) of \(torrent.formattedTotalSize)")
                LabeledContent("Progress", value: torrent.formattedProgress)
                if torrent.state == .downloading {
                    LabeledContent("Download Speed", value: torrent.formattedDownloadRate)
                    LabeledContent("Upload Speed", value: torrent.formattedUploadRate)
                    LabeledContent("Estimated Time", value: torrent.etaDescription)
                }
            }

            Section("Swarm") {
                LabeledContent("Connected Seeds", value: "\(torrent.numSeeds)")
                LabeledContent("Connected Peers", value: "\(torrent.numPeers)")
            }

            Section("Storage") {
                LabeledContent("Save Location") {
                    HStack(spacing: 6) {
                        Text(torrent.savePath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .font(.caption)
                        Button {
                            torrentManager.openInFinder(torrent.infoHash)
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.plain)
                        .help("Reveal in Finder")
                    }
                }

                LabeledContent("Info Hash") {
                    Text(torrent.infoHash)
                        .font(.caption2)
                        .fontDesign(.monospaced)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            if let error = torrent.error {
                Section("Error") {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Files Pane

    private func filesPane(torrent: TorrentModel) -> some View {
        VStack(spacing: 0) {
            if torrent.files.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Fetching metadata from peers...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredFiles(torrent.files)) { file in
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
                                .font(.system(size: 13))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.fileName)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                HStack(spacing: 6) {
                                    Text(file.formattedSize)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    if file.progress > 0 {
                                        Text(String(format: "• %.0f%%", file.progress * 100))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private func filteredFiles(_ files: [TorrentFileItem]) -> [TorrentFileItem] {
        let q = fileSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return files }
        return files.filter { $0.fileName.lowercased().contains(q) }
    }

    private func stateColor(for state: TorrentState) -> Color {
        switch state {
        case .downloading: return .blue
        case .finished, .seeding: return .green
        case .paused: return .orange
        case .checkingFiles: return .indigo
        case .downloadingMetadata: return .purple
        case .error: return .red
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
