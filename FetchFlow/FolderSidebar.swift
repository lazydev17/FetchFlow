import SwiftUI
import AppKit

struct FolderSidebar: View {
    @EnvironmentObject private var torrentManager: TorrentManager
    @ObservedObject private var networkService = NetworkInterfaceService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Library section title with breathing room below macOS window buttons
            Text("Library")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 38)
                .padding(.bottom, 6)

            // Category rows
            VStack(spacing: 3) {
                ForEach(TorrentFilter.allCases) { filter in
                    SidebarFilterRow(
                        filter: filter,
                        count: countForFilter(filter),
                        isSelected: torrentManager.activeFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            torrentManager.activeFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            // Aggregate speed footer
            sidebarFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var sidebarFooter: some View {
        VStack(spacing: 4) {
            Divider()

            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                    Text(ByteCountFormatter.string(fromByteCount: torrentManager.totalDownloadRate, countStyle: .binary) + "/s")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 3) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.green)
                    Text(ByteCountFormatter.string(fromByteCount: torrentManager.totalUploadRate, countStyle: .binary) + "/s")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if networkService.isConnectedToVPN {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                        .help("Routing via VPN (\(networkService.activeVPN?.name ?? "utun"))")
                } else if EngineSettings.killSwitchEnabled && EngineSettings.networkInterfaceMode == "auto_vpn" {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .help("Kill Switch Active: VPN disconnected, traffic paused")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    private func countForFilter(_ filter: TorrentFilter) -> Int {
        let all = Array(torrentManager.torrents.values)
        switch filter {
        case .all: return all.count
        case .downloading: return all.filter { $0.state == .downloading || $0.state == .queued || $0.state == .downloadingMetadata || $0.state == .checkingFiles }.count
        case .completed: return all.filter { $0.state == .finished || $0.state == .seeding }.count
        case .paused: return all.filter { $0.state == .paused }.count
        case .active: return all.filter { $0.downloadRate > 0 || $0.uploadRate > 0 }.count
        }
    }
}

// MARK: - Sidebar Row Button

private struct SidebarFilterRow: View {
    let filter: TorrentFilter
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: filter.iconName)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : filter.tintColor)
                    .frame(width: 18, alignment: .center)

                Text(filter.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)

                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.25) : Color.primary.opacity(0.08))
                        )
                        .foregroundStyle(isSelected ? Color.white : Color.secondary)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5.5)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.accentColor
                            : (isHovered ? Color.primary.opacity(0.06) : Color.clear)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
