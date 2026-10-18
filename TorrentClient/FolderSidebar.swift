import SwiftUI
import AppKit

struct FolderSidebar: View {
    @EnvironmentObject private var torrentManager: TorrentManager

    var body: some View {
        List(selection: $torrentManager.activeFilter) {
            Section("LIBRARY") {
                ForEach(TorrentFilter.allCases) { filter in
                    Label {
                        HStack {
                            Text(filter.rawValue)
                            Spacer()
                            Text("\(countForFilter(filter))")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: filter.iconName)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .tag(filter)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("TorrentClient")
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
