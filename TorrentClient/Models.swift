import Foundation
import SwiftUI

// MARK: - Torrent State
public enum TorrentState: String, CaseIterable, Codable {
    case checkingFiles = "Checking"
    case downloadingMetadata = "Fetching Metadata"
    case downloading = "Downloading"
    case queued = "Queued"
    case skipped = "No Files Selected"
    case finished = "Finished"
    case seeding = "Seeding"
    case paused = "Paused"
    case error = "Error"
    
    public var iconName: String {
        switch self {
        case .checkingFiles: return "arrow.triangle.2.circlepath"
        case .downloadingMetadata: return "antenna.radiowaves.left.and.right"
        case .downloading: return "arrow.down.circle.fill"
        case .queued: return "hourglass"
        case .skipped: return "minus.circle.fill"
        case .finished: return "checkmark.circle.fill"
        case .seeding: return "arrow.up.circle.fill"
        case .paused: return "pause.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }

    public var tintColor: Color {
        switch self {
        case .downloading: return .accentColor
        case .downloadingMetadata, .checkingFiles: return .purple
        case .queued: return .blue
        case .skipped: return .gray
        case .finished, .seeding: return .green
        case .paused: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Torrent Priority

public enum TorrentPriority: String, CaseIterable, Identifiable, Codable {
    case high = "High"
    case normal = "Normal"
    case low = "Low"

    public var id: String { rawValue }

    /// 0 = front of the download queue, 1 = leave order unchanged,
    /// 2 = back of the download queue.
    public var queuePosition: Int32 {
        switch self {
        case .high: return 0
        case .normal: return 1
        case .low: return 2
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
    public var totalUploaded: Int64
    public var totalSize: Int64
    public var totalWanted: Int64
    public var wantedDownloaded: Int64
    public var state: TorrentState
    public var numPeers: Int
    public var numSeeds: Int
    public var savePath: String
    public var priority: String
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
                totalUploaded: Int64 = 0,
                totalSize: Int64 = 0,
                totalWanted: Int64 = 0,
                wantedDownloaded: Int64 = 0,
                state: TorrentState = .downloading,
                numPeers: Int = 0,
                numSeeds: Int = 0,
                savePath: String = "",
                priority: String = "Normal",
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
        self.totalUploaded = totalUploaded
        self.totalSize = totalSize
        self.totalWanted = totalWanted
        self.wantedDownloaded = wantedDownloaded
        self.state = state
        self.numPeers = numPeers
        self.numSeeds = numSeeds
        self.savePath = savePath
        self.priority = priority
        self.files = files
        self.error = error
        self.dateAdded = dateAdded
    }
    
    /// True when the user action should be "Resume" rather than "Pause".
    /// Error-paused torrents can be resumed (which also clears the error).
    public var canResume: Bool {
        state == .paused || state == .error
    }

    public var priorityValue: TorrentPriority {
        TorrentPriority(rawValue: priority) ?? .normal
    }

    /// True when metadata is known and the user has excluded every file.
    /// libtorrent reports such a torrent as finished/complete, but there is
    /// nothing wanted, so the UI must not present it as a completed download.
    public var isFullySkipped: Bool {
        !files.isEmpty && files.allSatisfy { !$0.isIncluded }
    }

    public var displayProgress: Double {
        isFullySkipped ? 0 : progress
    }

    public var formattedProgress: String {
        return String(format: "%.1f%%", displayProgress * 100.0)
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

    public var formattedTotalUploaded: String {
        ByteCountFormatter.string(fromByteCount: totalUploaded, countStyle: .file)
    }

    public var ratioDescription: String {
        guard totalDownloaded > 0 else { return "0.000" }
        let ratio = Double(totalUploaded) / Double(totalDownloaded)
        return String(format: "%.3f", ratio)
    }

    public var magnetURI: String {
        let dn = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        // v2-only info hashes are 64 hex characters and must use the btmh
        // multihash form, not btih. Hybrid torrents are keyed by their v1 hash.
        if infoHash.count == 64 {
            return "magnet:?xt=urn:btmh:1220\(infoHash)&dn=\(dn)"
        }
        return "magnet:?xt=urn:btih:\(infoHash)&dn=\(dn)"
    }

    public var shortDateAdded: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: dateAdded)
    }

    public var fullDateAdded: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy, h:mm a"
        return formatter.string(from: dateAdded)
    }
    
    public var formattedTotalSize: String {
        if totalSize > 0 {
            return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        } else {
            return "Calculating..."
        }
    }
    
    public var etaDescription: String {
        if isFullySkipped {
            return TorrentState.skipped.rawValue
        }

        let remainingBytes: Int64
        if totalWanted > 0 {
            remainingBytes = max(0, totalWanted - wantedDownloaded)
        } else {
            remainingBytes = max(0, totalSize - totalDownloaded)
        }

        guard state == .downloading, downloadRate > 1024, remainingBytes > 0 else {
            return state.rawValue
        }
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
    case all = "All"
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

    public var tintColor: Color {
        switch self {
        case .all: return .accentColor
        case .downloading: return .accentColor
        case .completed: return .green
        case .paused: return .orange
        case .active: return .cyan
        }
    }
}
