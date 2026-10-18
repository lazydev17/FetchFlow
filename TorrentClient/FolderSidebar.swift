import SwiftUI
import AppKit

// MARK: - Settings-Style Glass Icon Badge
struct SettingsBadgeIcon: View {
    let systemImage: String
    let gradient: [Color]
    var size: CGFloat = 22
    var iconSize: CGFloat = 11

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 1.5, x: 0, y: 0.8)

            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }

    static func gradient(for state: TorrentState) -> [Color] {
        switch state {
        case .downloading:
            return [Color(white: 0.44), Color(white: 0.28)]
        case .finished, .seeding:
            return [Color(red: 0.18, green: 0.65, blue: 0.38), Color(red: 0.12, green: 0.52, blue: 0.28)]
        case .paused:
            return [Color(white: 0.55), Color(white: 0.40)]
        case .checkingFiles, .downloadingMetadata:
            return [Color(white: 0.48), Color(white: 0.35)]
        case .error:
            return [Color(red: 0.85, green: 0.25, blue: 0.25), Color(red: 0.70, green: 0.18, blue: 0.18)]
        }
    }

    static func gradient(for filter: TorrentFilter) -> [Color] {
        switch filter {
        case .all:
            return [Color(white: 0.50), Color(white: 0.36)]
        case .downloading:
            return [Color(white: 0.42), Color(white: 0.28)]
        case .completed:
            return [Color(red: 0.18, green: 0.65, blue: 0.38), Color(red: 0.12, green: 0.52, blue: 0.28)]
        case .paused:
            return [Color(white: 0.55), Color(white: 0.40)]
        case .active:
            return [Color(red: 0.86, green: 0.54, blue: 0.18), Color(red: 0.72, green: 0.40, blue: 0.12)]
        }
    }
}

struct FolderSidebar: View {
    @EnvironmentObject private var torrentManager: TorrentManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Library with breathing room below macOS window buttons
            Text("Library")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 40)
                .padding(.bottom, 6)

            // Category rows
            VStack(spacing: 2) {
                ForEach(TorrentFilter.allCases) { filter in
                    FinderSidebarRow(
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func countForFilter(_ filter: TorrentFilter) -> Int {
        let all = Array(torrentManager.torrents.values)
        switch filter {
        case .all: return all.count
        case .downloading: return all.filter { $0.state == .downloading || $0.state == .downloadingMetadata || $0.state == .checkingFiles }.count
        case .completed: return all.filter { $0.state == .finished || $0.state == .seeding }.count
        case .paused: return all.filter { $0.state == .paused }.count
        case .active: return all.filter { $0.downloadRate > 0 || $0.uploadRate > 0 }.count
        }
    }
}

private struct FinderSidebarRow: View {
    let filter: TorrentFilter
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: filter.iconName)
                    .font(.system(size: 15, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(Color(red: 0.15, green: 0.65, blue: 1.0))
                    .frame(width: 20, alignment: .center)

                Text(filter.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.85))

                Spacer()

                Text("\(count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(isSelected ? Color.secondary : Color.secondary.opacity(0.6))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.primary.opacity(0.12)
                            : (isHovered ? Color.primary.opacity(0.05) : Color.clear)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
