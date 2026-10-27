# Changelog

All notable changes to FetchFlow will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-10-28

### Performance & Engine
- **LLVM ThinLTO & Binary Optimization**: Enabled LLVM Thin Link-Time Optimization (`ThinLTO`), dead code elimination, and non-global symbol stripping in Release configurations, cutting executable size by 50%.
- **APFS Disk Flush Batching**: Implemented a 7 MiB disk write queue with unified OS page caching (`enable_os_cache`), 4 asynchronous disk I/O threads, and 2 dedicated hasher threads, eliminating periodic APFS I/O CPU spikes.
- **Main-Actor Pipeline & Batching**: Batched torrent progress updates across Objective-C++ and Swift, eliminating per-torrent asynchronous task allocations and slashing SwiftUI view body re-evaluations by ~95% during active multi-torrent swarms.
- **macOS App Nap Prevention**: Integrated automatic background power assertions (`ProcessInfo.beginActivity`) while torrents are actively downloading or checking, preventing macOS from throttling BSD socket timers or degrading network throughput when minimized or running in the background.
- **Conditional File Progress Polling**: Gated file progress traverses to active downloading and checking states, eliminating unnecessary libtorrent handle scans and heap allocations for finished, paused, or queued torrents.
- **Swarm Ramp-Up Acceleration**: Increased initial connection attempt speed and reduced connection timeouts to prune unresponsive peer handshakes twice as fast and saturate configured swarm limits in ~2s.

### Networking & Security
- **Automatic VPN Interface Routing**: Dynamically scans and binds to active VPN tunnels (`utun*`, `wg*`, Point-to-Point) with automatic hot-swap when VPN toggles.
- **VPN Kill Switch Protection**: Halts incoming and outgoing torrent traffic immediately if the VPN disconnects.
- **Network Profiles**: Fast, Conservative, and Custom connection presets with configurable global and per-torrent limits.
- **Smart Media Download Heuristic**: Automatically selects multi-episode TV series and music albums while skipping small sample clips.
- **Security Safeguards**: Automatically excludes and badges risky executables, scripts, and phishing links (`.exe`, `.scr`, `.bat`, `.cmd`, `.msi`, `.lnk`, etc.) with warning shield badges in the Files inspector.

### User Interface & Experience
- **macOS Native Design**: NavigationSplitView, vibrant accent colors, sidebar badge counters, and liquid glass styling matching macOS Finder.
- **Torrent Inspector**: Real-time swarm capacity indicators, peer analytics, tracker lists, and selective file hierarchy control.
- **Bandwidth Controls**: Quick speed presets (500 KB/s up to 100 MB/s), direct numeric entry, unit switcher (MB/s / KB/s), precision steppers, and real-time broadband equivalent (Mbps) calculation.
- **Toolbar Filtering**: Native picker for category filtering (All, Downloading, Completed, Paused, Active) with dynamic filter pill.
- **Priority Menus**: Native AppKit menu tracking for High/Normal/Low file priority controls to prevent submenu flickering.

### Torrent Management & System Integration
- **Magnet & `.torrent` Support**: Quickly add downloads by pasting magnet links or selecting `.torrent` files.
- **Selective File Downloading**: View full file hierarchy inside any torrent and toggle individual files to prioritize bandwidth and storage.
- **Finder Integration**: One-click reveal of completed files in macOS Finder (`NSWorkspace`).
- **Data Integrity & Auto-Recovery**: Automatic background local file verification and recovery when corrupted or empty resume data is encountered; persistent file selection priorities across restarts.
- **Hardened App Sandbox**: Secured macOS App Sandbox configured strictly with network client/server and Downloads entitlements.

### Distribution & Release
- **Sparkle 2 Auto-Update**: Seamless in-app update checks and automated Sparkle ed25519 signing.
- **GitHub Actions Release Pipeline**: Automated macOS 26 runners building DMG installers and ZIP distribution packages.

[1.0.0]: https://github.com/lazydev17/FetchFlow/releases/tag/v1.0.0
