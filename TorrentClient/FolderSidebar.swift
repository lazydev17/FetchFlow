import SwiftUI

struct FolderSidebar: View {
    @EnvironmentObject private var torrentManager: TorrentManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("LIBRARY")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            
            // Filter List
            List(TorrentFilter.allCases, id: \.self, selection: $torrentManager.activeFilter) { filter in
                SidebarRow(
                    filter: filter,
                    count: countForFilter(filter),
                    isSelected: torrentManager.activeFilter == filter
                )
                .tag(filter)
            }
            .listStyle(.sidebar)
            
            Divider()
            
            // Quick Locations
            VStack(alignment: .leading, spacing: 8) {
                Text("LOCATION")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                Button(action: {
                    NSWorkspace.shared.open(torrentManager.defaultSaveDirectory)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                            .foregroundStyle(Color.accentColor)
                        Text("Downloads")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Footer Live Bandwidth Status
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    Text(ByteCountFormatter.string(fromByteCount: torrentManager.totalDownloadRate, countStyle: .binary) + "/s")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text(ByteCountFormatter.string(fromByteCount: torrentManager.totalUploadRate, countStyle: .binary) + "/s")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.controlBackgroundColor).opacity(0.5))
        }
    }
    
    private func countForFilter(_ filter: TorrentFilter) -> Int {
        let all = Array(torrentManager.torrents.values)
        switch filter {
        case .all:
            return all.count
        case .downloading:
            return all.filter { $0.state == .downloading || $0.state == .downloadingMetadata || $0.state == .checkingFiles }.count
        case .completed:
            return all.filter { $0.state == .finished || $0.state == .seeding }.count
        case .paused:
            return all.filter { $0.state == .paused }.count
        case .active:
            return all.filter { $0.downloadRate > 0 || $0.uploadRate > 0 }.count
        }
    }
}

private struct SidebarRow: View {
    let filter: TorrentFilter
    let count: Int
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: filter.iconName)
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 18)
            
            Text(filter.rawValue)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            
            Spacer()
            
            if count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
                    )
            }
        }
        .padding(.vertical, 4)
    }
}
