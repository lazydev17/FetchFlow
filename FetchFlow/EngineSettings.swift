import Foundation

/// Central access to the user-facing engine settings.
///
/// The keys here intentionally match the `@AppStorage` keys used by
/// `SettingsView` and are also the keys consumed by `TorrentWrapper`'s
/// `applySettings:` bridge.
enum EngineSettings {
    // MARK: - UserDefaults keys

    static let customSavePathKey = "customSavePath"
    static let autoStartDownloadsKey = "autoStartDownloads"
    static let notifyOnCompletionKey = "notifyOnCompletion"
    static let limitDownloadRateKey = "limitDownloadRate"
    static let maxDownloadRateKBKey = "maxDownloadRateKB"
    static let limitUploadRateKey = "limitUploadRate"
    static let maxUploadRateKBKey = "maxUploadRateKB"
    static let maxActiveTorrentsKey = "maxActiveTorrents"
    static let enableDHTKey = "enableDHT"
    static let enableLSDKey = "enableLSD"
    static let enableUPnPKey = "enableUPnP"
    static let randomPortKey = "randomPort"
    static let customPortKey = "customPort"

    static let networkInterfaceModeKey = "networkInterfaceMode"
    static let killSwitchEnabledKey = "killSwitchEnabled"
    static let maxGlobalConnectionsKey = "maxGlobalConnections"
    static let mixedModePreferTCPKey = "mixedModePreferTCP"

    static let customSavePathBookmarkKey = "securityScope.customSavePath"

    // MARK: - Values

    private static var defaults: UserDefaults { .standard }

    static var customSavePath: String {
        defaults.string(forKey: customSavePathKey) ?? ""
    }

    static var autoStartDownloads: Bool {
        defaults.object(forKey: autoStartDownloadsKey) as? Bool ?? true
    }

    static var notifyOnCompletion: Bool {
        defaults.object(forKey: notifyOnCompletionKey) as? Bool ?? true
    }

    static var maxActiveTorrents: Int {
        let value = defaults.object(forKey: maxActiveTorrentsKey) as? Int ?? 5
        return min(max(value, 1), 50)
    }

    static var networkInterfaceMode: String {
        defaults.string(forKey: networkInterfaceModeKey) ?? "auto_vpn"
    }

    static var killSwitchEnabled: Bool {
        defaults.object(forKey: killSwitchEnabledKey) as? Bool ?? false
    }

    static var maxGlobalConnections: Int {
        let value = defaults.object(forKey: maxGlobalConnectionsKey) as? Int ?? 200
        return min(max(value, 20), 2000)
    }

    static var mixedModePreferTCP: Bool {
        defaults.object(forKey: mixedModePreferTCPKey) as? Bool ?? true
    }

    /// Payload consumed by `TorrentWrapper -applySettings:`.
    static var enginePayload: [String: Any] {
        [
            "enableDHT": defaults.object(forKey: enableDHTKey) as? Bool ?? true,
            "enableLSD": defaults.object(forKey: enableLSDKey) as? Bool ?? true,
            "enableUPnP": defaults.object(forKey: enableUPnPKey) as? Bool ?? true,
            "randomPort": defaults.object(forKey: randomPortKey) as? Bool ?? true,
            "customPort": defaults.object(forKey: customPortKey) as? Int ?? 6881,
            "limitDownloadRate": defaults.object(forKey: limitDownloadRateKey) as? Bool ?? false,
            "maxDownloadRateKB": defaults.object(forKey: maxDownloadRateKBKey) as? Int ?? 5000,
            "limitUploadRate": defaults.object(forKey: limitUploadRateKey) as? Bool ?? false,
            "maxUploadRateKB": defaults.object(forKey: maxUploadRateKBKey) as? Int ?? 1000,
            "maxActiveTorrents": maxActiveTorrents,
            "autoStartDownloads": autoStartDownloads,
            "networkInterfaceMode": networkInterfaceMode,
            "killSwitchEnabled": killSwitchEnabled,
            "maxGlobalConnections": maxGlobalConnections,
            "mixedModePreferTCP": mixedModePreferTCP,
            "boundInterface": "",
            "killSwitchActive": false
        ]
    }

    /// Stable signature so the manager only calls `applySettings` when a real
    /// engine-facing value changed (UserDefaults also posts on persistence writes).
    static var enginePayloadSignature: String {
        enginePayload
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: "&")
    }

    static var defaultSaveDirectory: URL {
        let path = customSavePath
        guard !path.isEmpty else { return downloadsDirectory }

        let url: URL
        if let bookmarked = resolveBookmark(forKey: customSavePathBookmarkKey) {
            url = bookmarked
        } else {
            url = URL(fileURLWithPath: path)
            if rememberActiveURL(url) {
                _ = url.startAccessingSecurityScopedResource()
            }
        }
        return url
    }

    static var downloadsDirectory: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
    }

    // MARK: - Security-scoped bookmarks

    private static let bookmarkLock = NSLock()
    private static var activeSecurityScopedURLs: [URL] = []

    static func torrentBookmarkKey(forPath path: String) -> String {
        "securityScope.torrent.\(path)"
    }

    static func folderBookmarkKey(forPath path: String) -> String {
        "securityScope.folder.\(path)"
    }

    static func saveBookmark(for url: URL, key: String) {
        do {
            let data = try url.bookmarkData(options: [.withSecurityScope],
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil)
            defaults.set(data, forKey: key)
        } catch {
            NSLog("Failed to create security-scoped bookmark for %@: %@", url.path, error.localizedDescription)
        }
    }

    static func resolveBookmark(forKey key: String) -> URL? {
        guard let data = defaults.data(forKey: key) else { return nil }

        var stale = false
        do {
            let url = try URL(resolvingBookmarkData: data,
                              options: [.withSecurityScope],
                              relativeTo: nil,
                              bookmarkDataIsStale: &stale)
            if stale {
                saveBookmark(for: url, key: key)
            }
            if rememberActiveURL(url) {
                _ = url.startAccessingSecurityScopedResource()
            }
            return url
        } catch {
            return nil
        }
    }

    static func saveTorrentBookmark(for url: URL) {
        saveBookmark(for: url, key: torrentBookmarkKey(forPath: url.path))
    }

    static func saveFolderBookmark(for url: URL) {
        saveBookmark(for: url, key: folderBookmarkKey(forPath: url.path))
    }

    static func resolveFileURL(forPath path: String) -> URL {
        if let url = resolveBookmark(forKey: torrentBookmarkKey(forPath: path)) {
            return url
        }
        let url = URL(fileURLWithPath: path)
        if rememberActiveURL(url) {
            _ = url.startAccessingSecurityScopedResource()
        }
        return url
    }

    static func resolveDirectory(forPath path: String) -> URL {
        if let url = resolveBookmark(forKey: folderBookmarkKey(forPath: path)) {
            return url
        }
        let url = URL(fileURLWithPath: path)
        if rememberActiveURL(url) {
            _ = url.startAccessingSecurityScopedResource()
        }
        return url
    }

    @discardableResult
    private static func rememberActiveURL(_ url: URL) -> Bool {
        bookmarkLock.lock()
        defer { bookmarkLock.unlock() }
        if activeSecurityScopedURLs.contains(url) {
            return false
        }
        activeSecurityScopedURLs.append(url)
        return true
    }
}
