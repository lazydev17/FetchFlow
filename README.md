# FetchFlow

[![License: MIT](https://img.shields.io/github/license/lazydev17/FetchFlow)](LICENSE)
[![Release](https://img.shields.io/github/v/release/lazydev17/FetchFlow)](https://github.com/lazydev17/FetchFlow/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-15.6+-blue)](https://www.apple.com/macos/)
[![Build](https://github.com/lazydev17/FetchFlow/actions/workflows/build.yml/badge.svg)](https://github.com/lazydev17/FetchFlow/actions/workflows/build.yml)

A native, high-performance **macOS BitTorrent Client** built with **SwiftUI** and powered by **libtorrent-rasterbar 2.0**.

Designed specifically for macOS with clean aesthetics, secure App Sandboxing, live bandwidth monitoring, and a fully native AppKit/SwiftUI experience.

## Download

**[⬇ Download Latest Release (DMG)](https://github.com/lazydev17/FetchFlow/releases/latest)** — macOS 15.6+, Apple Silicon

---

## Features

- **Magnet & `.torrent` Support**: Quickly add downloads by pasting magnet links or selecting `.torrent` files.
- **Selective File Downloading**: View the full file hierarchy inside any torrent and toggle individual files to prioritize bandwidth and storage.
- **Real-Time Transfer Metrics**: Live download/upload speed gauges, progress percentages, ETA calculations, and seed/peer counts.
- **Category Filters**: Filter downloads by status (*All*, *Downloading*, *Completed*, *Paused*, *Active*) from the toolbar.
- **Torrent Controls**: Pause, resume, and remove torrents with confirmation dialogs (optional deletion of downloaded files).
- **Finder Integration**: One-click reveal of completed files in macOS Finder (`NSWorkspace`).
- **Secure Sandboxing**: Hardened macOS App Sandbox configured strictly with required entitlements (Network client/server and Downloads folder).
- **Auto-Updates**: Built-in Sparkle integration with EdDSA-signed updates.
- **Self-Contained Executable**: Precompiled with statically linked `libtorrent-rasterbar`, `Boost`, and `OpenSSL`. The resulting application bundle is only ~10 MB and runs out-of-the-box without requiring Homebrew or external runtimes.

---

## Requirements

- **macOS**: 15.6 (Sequoia) or later
- **Architecture**: Apple Silicon (arm64)
- **Xcode** (for developers): 16.0+

---

## Getting Started (Developers)

The repository vendors all precompiled static libraries and headers in `Libraries/`, making the build process completely frictionless.

### 1. Clone the Repository
```bash
git clone https://github.com/lazydev17/FetchFlow.git
cd FetchFlow
```

### 2. Open and Run in Xcode
Open the Xcode project:
```bash
open FetchFlow.xcodeproj
```
Select the **FetchFlow** scheme and press **`⌘R`** (Build and Run).

### 3. Build from Terminal
You can also compile directly from the command line using `xcodebuild`:
```bash
xcodebuild \
  -project FetchFlow.xcodeproj \
  -scheme FetchFlow \
  -destination 'platform=macOS' \
  build
```

---

## Project Architecture

```
FetchFlow/
├── Libraries/                       # Precompiled C++ dependencies (Boost, OpenSSL, libtorrent, Sparkle)
├── FetchFlow/                       # Application source code
│   ├── FetchFlowApp.swift       # App lifecycle and window chrome setup
│   ├── ContentView.swift            # Resizable two-pane split layout
│   ├── FolderSidebar.swift          # Library category filters and bandwidth status
│   ├── FileList.swift               # Live torrent cards and controls
│   ├── TorrentInspectorView.swift   # Detailed torrent info panel
│   ├── AddTorrentSheet.swift        # Modal dialog for magnets & .torrent files
│   ├── SettingsView.swift           # Preferences UI
│   ├── EngineSettings.swift         # libtorrent session configuration
│   ├── Models.swift                 # TorrentModel, TorrentState, and TorrentFilter
│   ├── TorrentManager.swift         # @MainActor ObservableObject controller
│   ├── UpdaterViewModel.swift       # Sparkle auto-update controller
│   ├── TorrentWrapper.h / .mm       # Objective-C++ bridge to libtorrent C++ session
│   ├── FetchFlow-Bridging-Header.h
│   └── FetchFlow.entitlements   # App Sandbox network & file entitlements
├── scripts/                         # Build & release tooling
└── .github/workflows/               # CI/CD pipelines
```

---

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the [MIT License](LICENSE).

Third-party dependency licenses are listed in [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES).
