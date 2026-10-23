import Foundation
import Combine
import AppKit
@preconcurrency import UserNotifications

private struct SavedTorrentRecord: Codable {
    let uri: String
    let isFile: Bool
    let savePath: String
    let dateAdded: Date?
    let priority: String?
}

@MainActor
public class TorrentManager: ObservableObject {
    @Published public var torrents: [String: TorrentModel] = [:]
    @Published public var selectedInfoHash: String? = nil
    @Published public var checkedInfoHashes: Set<String> = []
    @Published public var activeFilter: TorrentFilter = .all
    @Published public var searchText: String = ""

    // Session-level problems (for example, the listen port could not be
    // opened). Torrent-specific errors are attached to their TorrentModel.
    @Published public var engineError: String?

    // Human-readable failure from the most recent add attempt. AddTorrentSheet
    // shows this instead of a generic message.
    @Published public var lastAddError: String?

    // Aggregated metrics
    @Published public var totalDownloadRate: Int64 = 0
    @Published public var totalUploadRate: Int64 = 0

    // Diagnostic warning for VPN blocks / network stall
    @Published public private(set) var vpnDiagnosticWarning: String? = nil

    public func dismissVpnWarning() {
        vpnDiagnosticWarning = nil
    }

    private let wrapper = TorrentWrapper()
    private let persistenceKey = "SavedTorrentsRecords_v1"

    private var settingsObserver: NSObjectProtocol?
    private var settingsApplyWorkItem: DispatchWorkItem?
    private var fileProgressTimer: Timer?
    private var lastEngineSettingsSignature: String?
    private var isShuttingDown = false

    public init() {
        let initialPayload = Self.effectivePayload()
        wrapper.applySettings(initialPayload)
        lastEngineSettingsSignature = Self.signature(for: initialPayload)

        setupCallbacks()
        setupObservers()
        startFileProgressTimer()
        loadPersistedTorrents()

        NetworkInterfaceService.shared.onInterfaceTopologyChanged = { [weak self] newVPN, _ in
            Task { @MainActor [weak self] in
                self?.handleNetworkInterfaceChanged(newVPN: newVPN)
            }
        }
    }

    deinit {
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.willTerminateNotification,
            object: nil
        )
        settingsApplyWorkItem?.cancel()
        fileProgressTimer?.invalidate()
        wrapper.stopAll()
    }

    // MARK: - Engine lifecycle

    private func setupObservers() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduleEngineSettingsApply()
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    @objc private func applicationWillTerminate() {
        shutdown()
    }

    /// UserDefaults posts on every keystroke/slider tick. Debounce briefly so
    /// a partially typed port (e.g. "688" on the way to "6881") or a slider
    /// mid-drag is never applied to the live session.
    private func scheduleEngineSettingsApply() {
        settingsApplyWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.applyEngineSettings()
            }
        }
        settingsApplyWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func applyEngineSettings(force: Bool = false) {
        let payload = Self.effectivePayload()
        let signature = Self.signature(for: payload)
        guard force || signature != lastEngineSettingsSignature else { return }
        lastEngineSettingsSignature = signature
        wrapper.applySettings(payload)
    }

    private func handleNetworkInterfaceChanged(newVPN: NetworkInterfaceInfo?) {
        guard !isShuttingDown else { return }
        let mode = EngineSettings.networkInterfaceMode
        let killSwitch = EngineSettings.killSwitchEnabled

        if let newVPN = newVPN {
            print("FetchFlow: VPN connected (\(newVPN.displayName)). Switching torrent traffic to VPN...")
            vpnDiagnosticWarning = nil
        } else {
            if killSwitch && mode == "auto_vpn" {
                print("FetchFlow: VPN disconnected with Kill Switch active. Transfers halted.")
                vpnDiagnosticWarning = "VPN disconnected. Transfers halted by Kill Switch to prevent unencrypted leaks."
            } else {
                print("FetchFlow: VPN disconnected. Reverting torrent traffic to default network route...")
                vpnDiagnosticWarning = nil
            }
        }

        applyEngineSettings(force: true)
        wrapper.reopenNetworkSockets()
    }

    private static func effectivePayload() -> [String: Any] {
        var payload = EngineSettings.enginePayload
        let mode = EngineSettings.networkInterfaceMode
        let killSwitch = EngineSettings.killSwitchEnabled
        let bound = NetworkInterfaceService.shared.resolveBoundInterface(mode: mode)
        let killSwitchActive = killSwitch && (mode == "auto_vpn" && bound == nil)

        payload["boundInterface"] = bound ?? ""
        payload["killSwitchActive"] = killSwitchActive

        return payload
    }

    private static func signature(for payload: [String: Any]) -> String {
        payload
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: "&")
    }

    private func startFileProgressTimer() {
        fileProgressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshSelectedFileProgress()
            }
        }
    }

    private func refreshSelectedFileProgress() {
        guard !isShuttingDown,
              let hash = selectedInfoHash,
              var item = torrents[hash],
              !item.files.isEmpty,
              let progress = wrapper.fileProgress(forTorrent: hash) else {
            return
        }

        var changed = false
        for (index, value) in progress.enumerated() where index < item.files.count {
            let newProgress = min(max(value.doubleValue, 0.0), 1.0)
            if abs(item.files[index].progress - newProgress) > 0.0001 {
                item.files[index].progress = newProgress
                changed = true
            }
        }
        if changed {
            torrents[hash] = item
        }
    }

    // MARK: - Callbacks

    private func setupCallbacks() {
        wrapper.setProgressCallback { [weak self] (infoHash, name, progress, dl, ul, totalDone, totalUp, totalSize, totalWanted, totalWantedDone, stateStr, peers, seeds) in
            guard let self = self else { return }

            Task { @MainActor in
                let key = infoHash as String
                let engineState = TorrentState(rawValue: stateStr as String) ?? .downloading

                if var item = self.torrents[key] {
                    item.progress = progress
                    item.downloadRate = dl
                    item.uploadRate = ul
                    item.totalDownloaded = totalDone
                    item.totalUploaded = totalUp
                    if totalSize > 0 {
                        item.totalSize = totalSize
                    }
                    item.totalWanted = totalWanted
                    item.wantedDownloaded = totalWantedDone
                    if !name.isEmpty && item.name == item.infoHash {
                        item.name = name as String
                    }
                    item.numPeers = Int(peers)
                    item.numSeeds = Int(seeds)

                    if item.isFullySkipped {
                        // libtorrent considers a torrent with no wanted files
                        // "finished". Present it as skipped instead.
                        item.state = .skipped
                        item.downloadRate = 0
                        item.error = nil
                    } else if engineState == .paused, let existing = item.error, !existing.isEmpty {
                        // A paused torrent with an error code is an error state;
                        // keep the message visible instead of showing a bare "Paused".
                        item.state = .error
                    } else {
                        if engineState != .error {
                            item.error = nil
                        }
                        item.state = engineState
                    }

                    self.torrents[key] = item
                } else {
                    let item = TorrentModel(
                        infoHash: key,
                        name: (name.isEmpty ? key : name) as String,
                        progress: progress,
                        downloadRate: dl,
                        uploadRate: ul,
                        totalDownloaded: totalDone,
                        totalUploaded: totalUp,
                        totalSize: totalSize,
                        totalWanted: totalWanted,
                        wantedDownloaded: totalWantedDone,
                        state: engineState,
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
                let previousInclusion = Dictionary(
                    uniqueKeysWithValues: (self.torrents[key]?.files ?? []).map { ($0.index, $0.isIncluded) }
                )

                var fileItems: [TorrentFileItem] = []
                for dict in rawFiles {
                    let idx = (dict["index"] as? NSNumber)?.intValue ?? 0
                    let path = (dict["path"] as? String) ?? ""
                    let size = (dict["size"] as? NSNumber)?.int64Value ?? 0
                    let prog = (dict["progress"] as? NSNumber)?.doubleValue ?? 0.0
                    let priority = (dict["priority"] as? NSNumber)?.intValue ?? 4
                    fileItems.append(TorrentFileItem(
                        index: idx,
                        path: path,
                        size: size,
                        progress: prog,
                        isIncluded: previousInclusion[idx] ?? (priority > 0)
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
                    if !fileItems.isEmpty && fileItems.allSatisfy({ !$0.isIncluded }) {
                        item.state = .skipped
                        item.downloadRate = 0
                    } else if item.state == .skipped {
                        item.state = .downloading
                    }
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
                    item.error = nil
                    self.torrents[key] = item
                    self.notifyCompletion(name: item.name)
                }
                self.recalculateAggregates()
            }
        }

        wrapper.setErrorCallback { [weak self] (infoHash, error) in
            guard let self = self else { return }

            Task { @MainActor in
                let key = infoHash as String
                let message = error as String

                if key.isEmpty {
                    self.engineError = message
                    return
                }

                if var item = self.torrents[key] {
                    item.state = .error
                    item.error = message
                    self.torrents[key] = item
                } else {
                    // A failed add, or a delete failure after the row was
                    // already removed. Surface it rather than discarding it.
                    self.engineError = message
                }
            }
        }

        wrapper.setRemovedCallback { [weak self] (infoHash) in
            guard let self = self else { return }

            Task { @MainActor in
                self.handleRemoved(infoHash as String)
            }
        }
    }

    private func handleRemoved(_ infoHash: String) {
        torrents.removeValue(forKey: infoHash)
        checkedInfoHashes.remove(infoHash)
        if selectedInfoHash == infoHash {
            selectedInfoHash = torrents.keys.first
        }
        removePersistedTorrent(key: infoHash)
        recalculateAggregates()
    }

    private func notifyCompletion(name: String) {
        guard EngineSettings.notifyOnCompletion else { return }

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "Download Complete"
            content.body = name
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            center.add(request)
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
        EngineSettings.defaultSaveDirectory
    }

    // MARK: - Actions

    @discardableResult
    public func addMagnet(_ magnetURI: String,
                          saveLocation: URL? = nil,
                          dateAdded: Date? = nil,
                          priority: TorrentPriority = .normal) -> String? {
        let trimmed = magnetURI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastAddError = "Magnet link is empty."
            return nil
        }
        let destination = saveLocation ?? defaultSaveDirectory

        if let infoHash = wrapper.addMagnet(trimmed, savePath: destination.path) {
            let key = infoHash as String
            let addedDate = dateAdded ?? Date()
            let effectivePriority = torrents[key]?.priorityValue ?? priority
            if torrents[key] == nil {
                torrents[key] = TorrentModel(
                    infoHash: key,
                    name: "Fetching metadata...",
                    savePath: destination.path,
                    priority: effectivePriority.rawValue,
                    dateAdded: addedDate
                )
            }
            if destination.path != EngineSettings.downloadsDirectory.path {
                EngineSettings.saveFolderBookmark(for: destination)
            }
            if effectivePriority != .normal {
                wrapper.setQueuePriority(effectivePriority.queuePosition, infoHash: key)
            }
            persistTorrent(key: key,
                           uri: trimmed,
                           isFile: false,
                           savePath: destination.path,
                           dateAdded: addedDate,
                           priority: effectivePriority)
            lastAddError = nil
            return key
        }

        lastAddError = wrapper.lastAddError() ?? "Failed to add magnet link."
        return nil
    }

    @discardableResult
    public func addTorrentFile(_ fileURL: URL,
                               saveLocation: URL? = nil,
                               dateAdded: Date? = nil,
                               priority: TorrentPriority = .normal) -> String? {
        let destination = saveLocation ?? defaultSaveDirectory

        EngineSettings.saveTorrentBookmark(for: fileURL)

        if let infoHash = wrapper.addTorrentFile(fileURL.path, savePath: destination.path) {
            let key = infoHash as String
            let addedDate = dateAdded ?? Date()
            let effectivePriority = torrents[key]?.priorityValue ?? priority
            if torrents[key] == nil {
                torrents[key] = TorrentModel(
                    infoHash: key,
                    name: fileURL.deletingPathExtension().lastPathComponent,
                    savePath: destination.path,
                    priority: effectivePriority.rawValue,
                    dateAdded: addedDate
                )
            }
            if destination.path != EngineSettings.downloadsDirectory.path {
                EngineSettings.saveFolderBookmark(for: destination)
            }
            if effectivePriority != .normal {
                wrapper.setQueuePriority(effectivePriority.queuePosition, infoHash: key)
            }
            persistTorrent(key: key,
                           uri: fileURL.path,
                           isFile: true,
                           savePath: destination.path,
                           dateAdded: addedDate,
                           priority: effectivePriority)
            lastAddError = nil
            return key
        }

        lastAddError = wrapper.lastAddError() ?? "Failed to parse torrent file."
        return nil
    }

    public func pauseTorrent(_ infoHash: String) {
        wrapper.pauseTorrent(infoHash)
        if var item = torrents[infoHash] {
            item.state = .paused
            item.downloadRate = 0
            item.uploadRate = 0
            item.error = nil
            torrents[infoHash] = item
        }
        recalculateAggregates()
    }

    public func resumeTorrent(_ infoHash: String) {
        wrapper.resumeTorrent(infoHash)
        if var item = torrents[infoHash] {
            item.state = .downloading
            item.error = nil
            torrents[infoHash] = item
            if item.priorityValue != .normal {
                wrapper.setQueuePriority(item.priorityValue.queuePosition, infoHash: infoHash)
            }
        }
    }

    public func setPriority(_ priority: TorrentPriority, for infoHash: String) {
        guard var item = torrents[infoHash] else { return }
        item.priority = priority.rawValue
        torrents[infoHash] = item

        wrapper.setQueuePriority(priority.queuePosition, infoHash: infoHash)
        updatePersistedPriority(key: infoHash, priority: priority)
    }

    public var hasActiveTorrents: Bool {
        torrents.values.contains { $0.state != .paused && $0.state != .finished && $0.state != .error && $0.state != .skipped }
    }

    public var hasCheckedTorrents: Bool {
        !checkedInfoHashes.isEmpty
    }

    public var checkedTorrents: [TorrentModel] {
        checkedInfoHashes.compactMap { torrents[$0] }
    }

    public var hasActiveCheckedTorrents: Bool {
        checkedTorrents.contains { $0.state != .paused && $0.state != .finished && $0.state != .error && $0.state != .skipped }
    }

    public func toggleCheck(_ infoHash: String) {
        if checkedInfoHashes.contains(infoHash) {
            checkedInfoHashes.remove(infoHash)
        } else {
            checkedInfoHashes.insert(infoHash)
            selectedInfoHash = infoHash
        }
    }

    public func toggleCheckAll(items: [TorrentModel]) {
        let currentItemHashes = Set(items.map { $0.infoHash })
        if checkedInfoHashes.isSuperset(of: currentItemHashes) {
            checkedInfoHashes.subtract(currentItemHashes)
        } else {
            checkedInfoHashes.formUnion(currentItemHashes)
            if let first = items.first {
                selectedInfoHash = first.infoHash
            }
        }
    }

    public func pauseChecked() {
        for hash in Array(checkedInfoHashes) {
            pauseTorrent(hash)
        }
    }

    public func resumeChecked() {
        for hash in Array(checkedInfoHashes) {
            resumeTorrent(hash)
        }
    }

    public func removeChecked(deleteFiles: Bool = false) {
        for hash in Array(checkedInfoHashes) {
            removeTorrent(hash, deleteFiles: deleteFiles)
        }
        checkedInfoHashes.removeAll()
    }

    public func pauseAll() {
        for hash in Array(torrents.keys) {
            pauseTorrent(hash)
        }
    }

    public func resumeAll() {
        for hash in Array(torrents.keys) {
            resumeTorrent(hash)
        }
    }

    public func removeTorrent(_ infoHash: String, deleteFiles: Bool = false) {
        wrapper.removeTorrent(infoHash, deleteFiles: deleteFiles)
        handleRemoved(infoHash)
    }

    public func toggleFileIncluded(infoHash: String, fileIndex: Int) {
        guard var item = torrents[infoHash], fileIndex >= 0, fileIndex < item.files.count else { return }
        let current = item.files[fileIndex].isIncluded
        let newIncluded = !current
        item.files[fileIndex].isIncluded = newIncluded

        if item.files.allSatisfy({ !$0.isIncluded }) {
            item.state = .skipped
            item.downloadRate = 0
        } else if item.state == .skipped {
            item.state = .downloading
        }
        torrents[infoHash] = item

        // 0 = don't download, 4 = default priority in libtorrent
        let priority = newIncluded ? 4 : 0
        wrapper.setFilePriority(Int32(fileIndex), priority: Int32(priority), infoHash: infoHash)
        wrapper.saveResumeData(forTorrent: infoHash)
    }

    public func setAllFilesIncluded(infoHash: String, included: Bool) {
        guard var item = torrents[infoHash], !item.files.isEmpty else { return }
        for i in 0..<item.files.count {
            // Safeguard: Never automatically batch-select risky files
            if included && item.files[i].isRisky {
                item.files[i].isIncluded = false
                wrapper.setFilePriority(Int32(i), priority: 0, infoHash: infoHash)
                continue
            }
            item.files[i].isIncluded = included
            let priority = included ? 4 : 0
            wrapper.setFilePriority(Int32(i), priority: Int32(priority), infoHash: infoHash)
        }
        if included {
            if item.state == .skipped {
                item.state = .downloading
            }
        } else {
            item.state = .skipped
            item.downloadRate = 0
        }
        torrents[infoHash] = item
        wrapper.saveResumeData(forTorrent: infoHash)
    }

    public func openInFinder(_ infoHash: String) {
        guard let item = torrents[infoHash] else { return }
        let saveURL = EngineSettings.resolveDirectory(forPath: item.savePath)
        let itemURL = saveURL.appendingPathComponent(item.name)
        if FileManager.default.fileExists(atPath: itemURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([itemURL])
        } else {
            NSWorkspace.shared.open(saveURL)
        }
    }

    public func stopAll() {
        shutdown()
    }

    private func shutdown() {
        guard !isShuttingDown else { return }
        isShuttingDown = true
        fileProgressTimer?.invalidate()
        fileProgressTimer = nil
        wrapper.stopAll()
    }

    // MARK: - Filtering

    public var filteredTorrents: [TorrentModel] {
        var items = Array(torrents.values)

        switch activeFilter {
        case .all:
            break
        case .downloading:
            items = items.filter {
                $0.state == .downloading
                    || $0.state == .queued
                    || $0.state == .downloadingMetadata
                    || $0.state == .checkingFiles
            }
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

    private func persistTorrent(key: String,
                                uri: String,
                                isFile: Bool,
                                savePath: String,
                                dateAdded: Date? = nil,
                                priority: TorrentPriority? = nil) {
        var records = loadRawRecords()
        let date = dateAdded ?? records[key]?.dateAdded ?? Date()
        let savedPriority = priority?.rawValue
            ?? records[key]?.priority
            ?? TorrentPriority.normal.rawValue
        records[key] = SavedTorrentRecord(
            uri: uri,
            isFile: isFile,
            savePath: savePath,
            dateAdded: date,
            priority: savedPriority
        )
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }

    private func updatePersistedPriority(key: String, priority: TorrentPriority) {
        var records = loadRawRecords()
        guard let record = records[key] else { return }
        records[key] = SavedTorrentRecord(
            uri: record.uri,
            isFile: record.isFile,
            savePath: record.savePath,
            dateAdded: record.dateAdded,
            priority: priority.rawValue
        )
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

        // Restore oldest-first so libtorrent's queue order roughly matches the
        // order in which the user originally added the torrents.
        let ordered = records.sorted {
            ($0.value.dateAdded ?? .distantPast) < ($1.value.dateAdded ?? .distantPast)
        }

        for (oldKey, record) in ordered {
            let saveURL = EngineSettings.resolveDirectory(forPath: record.savePath)

            var newKey: String?
            if record.isFile {
                let fileURL = EngineSettings.resolveFileURL(forPath: record.uri)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    newKey = addTorrentFile(
                        fileURL,
                        saveLocation: saveURL,
                        dateAdded: record.dateAdded,
                        priority: TorrentPriority(rawValue: record.priority ?? "Normal") ?? .normal
                    )
                }
            } else {
                newKey = addMagnet(
                    record.uri,
                    saveLocation: saveURL,
                    dateAdded: record.dateAdded,
                    priority: TorrentPriority(rawValue: record.priority ?? "Normal") ?? .normal
                )
            }

            // Migrate records written by older builds that used a truncated
            // v2 info hash as the dictionary key.
            if let newKey, newKey != oldKey {
                removePersistedTorrent(key: oldKey)
            }
        }
    }
}
