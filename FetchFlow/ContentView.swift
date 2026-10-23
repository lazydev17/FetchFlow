//
//  ContentView.swift
//  FetchFlow
//

import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var torrentManager: TorrentManager
    @State private var isPresentingAddSheet = false
    @State private var showingDeleteCheckedConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            if let warning = torrentManager.vpnDiagnosticWarning {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(warning)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)
                    Spacer()
                    Button("Dismiss") {
                        torrentManager.dismissVpnWarning()
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.12))
                .overlay(Divider(), alignment: .bottom)
            }

            FileList(isPresentingAddSheet: $isPresentingAddSheet)
        }
        .frame(minWidth: 780, minHeight: 480)
        .searchable(text: $torrentManager.searchText, placement: .toolbar, prompt: "Search in downloads…")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Menu {
                    Picker("Filter", selection: $torrentManager.activeFilter) {
                        ForEach(TorrentFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Text("\(Text(Image(nsImage: .filterFunnel)).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary))  \(Text(torrentManager.activeFilter.rawValue).font(.system(size: 12, weight: .medium)).foregroundStyle(.primary))  \(Text(Image(systemName: "chevron.up.chevron.down")).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary))")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.8)
                        )
                        .contentShape(Capsule())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .padding(.horizontal, 4)
                .fixedSize()
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
        .alert("Download Engine Error", isPresented: Binding(
            get: { torrentManager.engineError != nil },
            set: { presented in
                if !presented { torrentManager.engineError = nil }
            }
        )) {
            Button("OK", role: .cancel) {
                torrentManager.engineError = nil
            }
        } message: {
            Text(torrentManager.engineError ?? "Unknown engine error")
        }
        .dropDestination(for: URL.self) { urls, _ in
            var handled = false
            for url in urls {
                let ext = url.pathExtension.lowercased()
                if url.isFileURL && ext == "torrent" {
                    if torrentManager.addTorrentFile(url) == nil {
                        torrentManager.engineError = torrentManager.lastAddError
                            ?? "Failed to add torrent file."
                    }
                    handled = true
                } else if url.scheme?.lowercased() == "magnet" {
                    if torrentManager.addMagnet(url.absoluteString) == nil {
                        torrentManager.engineError = torrentManager.lastAddError
                            ?? "Failed to add magnet link."
                    }
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

// MARK: - Funnel Filter Icon

private extension NSImage {
    /// Crisp vector template funnel matching standard filter icon designs
    static let filterFunnel: NSImage = {
        let size = NSSize(width: 10.5, height: 10.5)
        let img = NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath()
            let w = rect.width
            let h = rect.height
            // Draw funnel polygon (flipped: false -> y=0 is bottom, y=h is top)
            path.move(to: NSPoint(x: w * 0.05, y: h * 0.95))
            path.line(to: NSPoint(x: w * 0.95, y: h * 0.95))
            path.line(to: NSPoint(x: w * 0.62, y: h * 0.50))
            path.line(to: NSPoint(x: w * 0.62, y: h * 0.08))
            path.line(to: NSPoint(x: w * 0.38, y: h * 0.08))
            path.line(to: NSPoint(x: w * 0.38, y: h * 0.50))
            path.close()
            path.lineJoinStyle = .round
            NSColor.black.setFill()
            path.fill()
            return true
        }
        img.isTemplate = true
        return img
    }()
}
