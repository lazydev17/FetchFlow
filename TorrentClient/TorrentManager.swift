import Foundation
import Combine

// --- NEW: A clearer way to represent the torrent's state ---
enum TorrentState: String {
    case checkingFiles = "Checking"
    case downloadingMetadata = "Fetching Metadata"
    case downloading = "Downloading"
    case finished = "Finished"
    case seeding = "Seeding"
    case paused = "Paused"
    case error = "Error"
}

// --- UPDATED: The model now holds more useful information for the UI ---
struct TorrentModel: Identifiable {
    let id = UUID()
    let infoHash: String
    var name: String
    var progress: Double
    var downloadRate: Int
    var uploadRate: Int
    var state: TorrentState
    var error: String? // To display errors to the user
}

@MainActor
class TorrentManager: ObservableObject {
    @Published var torrents: [String: TorrentModel] = [:] // keyed by infoHash

    private let wrapper = TorrentWrapper()

    init() {
        // --- UPDATED: The callback now provides more data ---
        wrapper.setProgressCallback { [weak self] (infoHash, name, progress, dl, ul, stateStr) in
            guard let self = self else { return }
            
            Task { @MainActor in
                let key = infoHash as String
                let state = TorrentState(rawValue: stateStr as String) ?? .downloading
                
                if var t = self.torrents[key] {
                    t.progress = progress
                    t.downloadRate = Int(dl)
                    t.uploadRate = Int(ul)
                    t.name = name as String
                    t.state = state
                    self.torrents[key] = t
                } else {
                    let t = TorrentModel(infoHash: key,
                                         name: name as String,
                                         progress: progress,
                                         downloadRate: Int(dl),
                                         uploadRate: Int(ul),
                                         state: state)
                    self.torrents[key] = t
                }
            }
        }
        
        // --- NEW: Set up a callback to handle errors ---
        wrapper.setErrorCallback { [weak self] (infoHash, error) in
            guard let self = self else { return }
            
            Task { @MainActor in
                let key = infoHash as String
                if self.torrents[key] != nil {
                    self.torrents[key]?.state = .error
                    self.torrents[key]?.error = error as String
                }
            }
        }
    }

    // --- UPDATED: Now safely unwraps the Downloads directory URL ---
    func addMagnet(_ magnet: String) {
        guard let saveURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            print("Error: Could not find the Downloads directory.")
            return
        }
        wrapper.addMagnet(magnet, savePath: saveURL.path)
    }

    func stopAll() {
        wrapper.stopAll()
    }
}
