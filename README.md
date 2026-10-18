# TorrentClient (FetchFlow)

A native, high-performance **macOS BitTorrent Client** built with **SwiftUI** and powered by **libtorrent-rasterbar 2.0**.

Designed specifically for macOS with clean aesthetics, secure App Sandboxing, live bandwidth monitoring, and a fully native AppKit/SwiftUI experience.

---

## Features

- **Magnet & `.torrent` Support**: Quickly add downloads by pasting magnet links or selecting `.torrent` files.
- **Selective File Downloading**: View the full file hierarchy inside any torrent and toggle individual files to prioritize bandwidth and storage.
- **Real-Time Transfer Metrics**: Live download/upload speed gauges, progress percentages, ETA calculations, and seed/peer counts.
- **Category Filters**: Filter downloads by status (*All Downloads*, *Downloading*, *Completed*, *Paused*, *Active*) with live badge counters.
- **Torrent Controls**: Pause, resume, and remove torrents with confirmation dialogs (optional deletion of downloaded files).
- **Finder Integration**: One-click reveal of completed files in macOS Finder (`NSWorkspace`).
- **Secure Sandboxing**: Hardened macOS App Sandbox configured strictly with required entitlements (Network client/server and Downloads folder).
- **Self-Contained Executable**: Precompiled with statically linked `libtorrent-rasterbar`, `Boost`, and `OpenSSL`. The resulting application bundle is only ~10 MB and runs out-of-the-box without requiring Homebrew or external runtimes.

---

## Requirements

- **macOS**: 15.0 (Sequoia) or later
- **Architecture**: Universal (Apple Silicon & Intel)
- **Xcode** (for developers): 16.0+

---

## Getting Started (Developers)

The repository vendors all precompiled static libraries and headers in `TorrentClient/Libraries/`, making the build process completely frictionless.

### 1. Clone the Repository
```bash
git clone https://github.com/<your-username>/Torrent-Client.git
cd Torrent-Client
```

### 2. Open and Run in Xcode
Open the Xcode project:
```bash
open TorrentClient/TorrentClient.xcodeproj
```
Select the **TorrentClient** scheme and press **`⌘R`** (Build and Run).

### 3. Build from Terminal
You can also compile directly from the command line using `xcodebuild`:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project TorrentClient/TorrentClient.xcodeproj \
  -scheme TorrentClient \
  -destination 'platform=macOS' \
  build
```

---

## Project Architecture

```
Torrent-Client/
├── .agents/skills/              # Native macOS & SwiftUI AI developer skills
├── .gitignore                   # Excludes DerivedData, user states, and build caches
├── README.md                    # Project documentation
└── TorrentClient/
    ├── Libraries/               # Precompiled C++ dependencies (Boost, OpenSSL, libtorrent)
    │   ├── boost_include/
    │   ├── boost_lib/
    │   ├── libtorrent_include/
    │   ├── libtorrent-rasterbar.a
    │   ├── openssl_include/
    │   └── openssl_lib/
    └── TorrentClient/           # Application source code
        ├── TorrentClientApp.swift       # App lifecycle and window chrome setup
        ├── ContentView.swift            # Resizable two-pane split layout
        ├── CustomToolbarView.swift      # Integrated search and top action bar
        ├── FolderSidebar.swift          # Library category filters and bandwidth status
        ├── FileList.swift               # Live torrent cards, file inspector & controls
        ├── AddTorrentSheet.swift        # Modal dialog for magnets & .torrent files
        ├── Models.swift                 # TorrentModel, TorrentState, and TorrentFilter
        ├── TorrentManager.swift         # @MainActor ObservableObject controller
        ├── TorrentWrapper.h / .mm       # Objective-C++ bridge to libtorrent C++ session
        ├── TorrentClient-Bridging-Header.h
        └── TorrentClient.entitlements   # App Sandbox network & file entitlements
```

---

## License

This project is licensed under the MIT License.
