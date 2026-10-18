import Foundation

// MARK: - Torrent State
public enum TorrentState: String, CaseIterable, Codable {
    case checkingFiles = "Checking"
    case downloadingMetadata = "Fetching Metadata"
    case downloading = "Downloading"
    case finished = "Finished"
    case seeding = "Seeding"
    case paused = "Paused"
    case error = "Error"
    
    public var iconName: String {
        switch self {
        case .checkingFiles: return "arrow.triangle.2.circlepath"
        case .downloadingMetadata: return "antenna.radiowaves.left.and.right"
        case .downloading: return "arrow.down.circle.fill"
        case .finished: return "checkmark.circle.fill"
        case .seeding: return "arrow.up.circle.fill"
        case .paused: return "pause.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }
}

// MARK: - Torrent File Item
public struct TorrentFileItem: Identifiable, Hashable, Codable {
    public var id: Int { index }
    public let index: Int
    public let path: String
    public let size: Int64
    public var progress: Double
    public var isIncluded: Bool
    
    public var fileName: String {
        return (path as NSString).lastPathComponent
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - Torrent Model
public struct TorrentModel: Identifiable, Hashable {
    public let id: UUID
    public let infoHash: String
    public var name: String
    public var progress: Double
    public var downloadRate: Int64
    public var uploadRate: Int64
    public var totalDownloaded: Int64
    public var totalSize: Int64
    public var state: TorrentState
    public var numPeers: Int
    public var numSeeds: Int
    public var savePath: String
    public var files: [TorrentFileItem]
    public var error: String?
    public var dateAdded: Date
    
    public init(id: UUID = UUID(),
                infoHash: String,
                name: String,
                progress: Double = 0.0,
                downloadRate: Int64 = 0,
                uploadRate: Int64 = 0,
                totalDownloaded: Int64 = 0,
                totalSize: Int64 = 0,
                state: TorrentState = .downloading,
                numPeers: Int = 0,
                numSeeds: Int = 0,
                savePath: String = "",
                files: [TorrentFileItem] = [],
                error: String? = nil,
                dateAdded: Date = Date()) {
        self.id = id
        self.infoHash = infoHash
        self.name = name
        self.progress = progress
        self.downloadRate = downloadRate
        self.uploadRate = uploadRate
        self.totalDownloaded = totalDownloaded
        self.totalSize = totalSize
        self.state = state
        self.numPeers = numPeers
        self.numSeeds = numSeeds
        self.savePath = savePath
        self.files = files
        self.error = error
        self.dateAdded = dateAdded
    }
    
    public var formattedProgress: String {
        return String(format: "%.1f%%", progress * 100.0)
    }
    
    public var formattedDownloadRate: String {
        guard downloadRate > 0 else { return "0 KB/s" }
        return "\(ByteCountFormatter.string(fromByteCount: downloadRate, countStyle: .binary))/s"
    }
    
    public var formattedUploadRate: String {
        guard uploadRate > 0 else { return "0 KB/s" }
        return "\(ByteCountFormatter.string(fromByteCount: uploadRate, countStyle: .binary))/s"
    }
    
    public var formattedTotalDownloaded: String {
        ByteCountFormatter.string(fromByteCount: totalDownloaded, countStyle: .file)
    }
    
    public var formattedTotalSize: String {
        if totalSize > 0 {
            return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        } else {
            return "Calculating..."
        }
    }
    
    public var etaDescription: String {
        guard state == .downloading, downloadRate > 1024, totalSize > totalDownloaded else {
            return state.rawValue
        }
        let remainingBytes = totalSize - totalDownloaded
        let seconds = Double(remainingBytes) / Double(downloadRate)
        if seconds < 60 {
            return String(format: "%ds left", Int(seconds))
        } else if seconds < 3600 {
            return String(format: "%dm left", Int(seconds / 60))
        } else {
            let hours = Int(seconds / 3600)
            let mins = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(mins)m left"
        }
    }
}

// MARK: - Torrent Filter / Category
public enum TorrentFilter: String, CaseIterable, Identifiable {
    case all = "All Downloads"
    case downloading = "Downloading"
    case completed = "Completed"
    case paused = "Paused"
    case active = "Active"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .all: return "tray.full"
        case .downloading: return "arrow.down.circle"
        case .completed: return "checkmark.circle"
        case .paused: return "pause.circle"
        case .active: return "bolt.circle"
        }
    }
}
