import Foundation
import Combine
import AppKit

private struct SavedTorrentRecord: Codable {
    let uri: String
    let isFile: Bool
    let savePath: String
}

@MainActor
public class TorrentManager: ObservableObject {
    @Published public var torrents: [String: TorrentModel] = [:]
    @Published public var selectedInfoHash: String? = nil
    @Published public var activeFilter: TorrentFilter = .all
    @Published public var searchText: String = ""
    
    // Aggregated metrics
    @Published public var totalDownloadRate: Int64 = 0
    @Published public var totalUploadRate: Int64 = 0
    
    private let wrapper = TorrentWrapper()
    private let persistenceKey = "SavedTorrentsRecords_v1"
    
    public init() {
        setupCallbacks()
        loadPersistedTorrents()
    }
    
    private func setupCallbacks() {
        wrapper.setProgressCallback { [weak self] (infoHash, name, progress, dl, ul, totalDone, totalSize, stateStr, peers, seeds) in
            guard let self = self else { return }
            
            Task { @MainActor in
                let key = infoHash as String
                let state = TorrentState(rawValue: stateStr as String) ?? .downloading
                
                if var item = self.torrents[key] {
                    item.progress = progress
                    item.downloadRate = dl
                    item.uploadRate = ul
                    item.totalDownloaded = totalDone
                    if totalSize > 0 {
                        item.totalSize = totalSize
                    }
                    if !name.isEmpty && item.name == item.infoHash {
                        item.name = name as String
                    }
                    item.state = state
                    item.numPeers = Int(peers)
                    item.numSeeds = Int(seeds)
                    self.torrents[key] = item
                } else {
                    let item = TorrentModel(
                        infoHash: key,
                        name: (name.isEmpty ? key : name) as String,
                        progress: progress,
                        downloadRate: dl,
                        uploadRate: ul,
                        totalDownloaded: totalDone,
                        totalSize: totalSize,
                        state: state,
                        numPeers: Int(peers),
                        numSeeds: Int(seeds),
                        savePath: self.defaultSaveDirectory.path
                    )
                    self.torrents[key] = item
                }
                self.recalculateAggregates()
            }
        }
        
        wrapper.setMetadataCallback { [weak self] (infoHash, name, totalSize, rawFiles) in
            guard let self = self else { return }
            
            Task { @MainActor in
                let key = infoHash as String
                var fileItems: [TorrentFileItem] = []
                for dict in rawFiles {
                    let idx = (dict["index"] as? NSNumber)?.intValue ?? 0
                    let path = (dict["path"] as? String) ?? ""
                    let size = (dict["size"] as? NSNumber)?.int64Value ?? 0
                    let prog = (dict["progress"] as? NSNumber)?.doubleValue ?? 0.0
                    fileItems.append(TorrentFileItem(
                        index: idx,
                        path: path,
                        size: size,
                        progress: prog,
                        isIncluded: true
                    ))
                }
                
                if var item = self.torrents[key] {
                    if !name.isEmpty {
                        item.name = name as String
                    }
                    if totalSize > 0 {
                        item.totalSize = totalSize
                    }
                    item.files = fileItems
                    self.torrents[key] = item
                }
            }
        }
        
        wrapper.setFinishedCallback { [weak self] (infoHash) in
            guard let self = self else { return }
            
            Task { @MainActor in
                let key = infoHash as String
                if var item = self.torrents[key] {
                    item.state = .finished
                    item.progress = 1.0
                    item.downloadRate = 0
                    self.torrents[key] = item
                }
                self.recalculateAggregates()
            }
        }
        
        wrapper.setErrorCallback { [weak self] (infoHash, error) in
            guard let self = self else { return }
            
            Task { @MainActor in
                let key = infoHash as String
                if var item = self.torrents[key] {
                    item.state = .error
                    item.error = error as String
                    self.torrents[key] = item
                }
            }
        }
    }
    
    private func recalculateAggregates() {
        var dl: Int64 = 0
        var ul: Int64 = 0
        for item in torrents.values {
            dl += item.downloadRate
            ul += item.uploadRate
        }
        self.totalDownloadRate = dl
        self.totalUploadRate = ul
    }
    
    public var defaultSaveDirectory: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
    }
    
    // MARK: - Actions
    
    @discardableResult
    public func addMagnet(_ magnetURI: String, saveLocation: URL? = nil) -> String? {
        let trimmed = magnetURI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let destination = saveLocation ?? defaultSaveDirectory
        
        if let infoHash = wrapper.addMagnet(trimmed, savePath: destination.path) {
            let key = infoHash as String
            if torrents[key] == nil {
                torrents[key] = TorrentModel(
                    infoHash: key,
                    name: "Fetching metadata...",
                    savePath: destination.path
                )
            }
            persistTorrent(key: key, uri: trimmed, isFile: false, savePath: destination.path)
            return key
        }
        return nil
    }
    
    @discardableResult
    public func addTorrentFile(_ fileURL: URL, saveLocation: URL? = nil) -> String? {
        let destination = saveLocation ?? defaultSaveDirectory
        
        if let infoHash = wrapper.addTorrentFile(fileURL.path, savePath: destination.path) {
            let key = infoHash as String
            if torrents[key] == nil {
                torrents[key] = TorrentModel(
                    infoHash: key,
                    name: fileURL.deletingPathExtension().lastPathComponent,
                    savePath: destination.path
                )
            }
            persistTorrent(key: key, uri: fileURL.path, isFile: true, savePath: destination.path)
            return key
        }
        return nil
    }
    
    public func pauseTorrent(_ infoHash: String) {
        wrapper.pauseTorrent(infoHash)
        if var item = torrents[infoHash] {
            item.state = .paused
            item.downloadRate = 0
            item.uploadRate = 0
            torrents[infoHash] = item
        }
        recalculateAggregates()
    }
    
    public func resumeTorrent(_ infoHash: String) {
        wrapper.resumeTorrent(infoHash)
        if var item = torrents[infoHash] {
            item.state = .downloading
            torrents[infoHash] = item
        }
    }
    
    public func removeTorrent(_ infoHash: String, deleteFiles: Bool = false) {
        wrapper.removeTorrent(infoHash, deleteFiles: deleteFiles)
        torrents.removeValue(forKey: infoHash)
        if selectedInfoHash == infoHash {
            selectedInfoHash = torrents.keys.first
        }
        removePersistedTorrent(key: infoHash)
        recalculateAggregates()
    }
    
    public func toggleFileIncluded(infoHash: String, fileIndex: Int) {
        guard var item = torrents[infoHash], fileIndex < item.files.count else { return }
        let current = item.files[fileIndex].isIncluded
        let newIncluded = !current
        item.files[fileIndex].isIncluded = newIncluded
        torrents[infoHash] = item
        
        // 0 = don't download, 4 = default priority in libtorrent
        let priority = newIncluded ? 4 : 0
        wrapper.setFilePriority(Int32(fileIndex), priority: Int32(priority), infoHash: infoHash)
    }
    
    public func openInFinder(_ infoHash: String) {
        guard let item = torrents[infoHash] else { return }
        let saveURL = URL(fileURLWithPath: item.savePath)
        let itemURL = saveURL.appendingPathComponent(item.name)
        if FileManager.default.fileExists(atPath: itemURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([itemURL])
        } else {
            NSWorkspace.shared.open(saveURL)
        }
    }
    
    public func stopAll() {
        wrapper.stopAll()
    }
    
    // MARK: - Filtering
    
    public var filteredTorrents: [TorrentModel] {
        var items = Array(torrents.values)
        
        switch activeFilter {
        case .all:
            break
        case .downloading:
            items = items.filter { $0.state == .downloading || $0.state == .downloadingMetadata || $0.state == .checkingFiles }
        case .completed:
            items = items.filter { $0.state == .finished || $0.state == .seeding }
        case .paused:
            items = items.filter { $0.state == .paused }
        case .active:
            items = items.filter { $0.downloadRate > 0 || $0.uploadRate > 0 }
        }
        
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            items = items.filter { $0.name.lowercased().contains(query) || $0.infoHash.lowercased().contains(query) }
        }
        
        return items.sorted(by: { $0.dateAdded > $1.dateAdded })
    }
    
    public var selectedTorrent: TorrentModel? {
        if let key = selectedInfoHash {
            return torrents[key]
        }
        return nil
    }
    
    // MARK: - Persistence
    
    private func persistTorrent(key: String, uri: String, isFile: Bool, savePath: String) {
        var records = loadRawRecords()
        records[key] = SavedTorrentRecord(uri: uri, isFile: isFile, savePath: savePath)
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }
    
    private func removePersistedTorrent(key: String) {
        var records = loadRawRecords()
        records.removeValue(forKey: key)
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }
    
    private func loadRawRecords() -> [String: SavedTorrentRecord] {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let dict = try? JSONDecoder().decode([String: SavedTorrentRecord].self, from: data) else {
            return [:]
        }
        return dict
    }
    
    private func loadPersistedTorrents() {
        let records = loadRawRecords()
        for (_, record) in records {
            let saveURL = URL(fileURLWithPath: record.savePath)
            if record.isFile {
                let fileURL = URL(fileURLWithPath: record.uri)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    addTorrentFile(fileURL, saveLocation: saveURL)
                }
            } else {
                addMagnet(record.uri, saveLocation: saveURL)
            }
        }
    }
}
