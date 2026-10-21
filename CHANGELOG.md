# Changelog

All notable changes to FetchFlow will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.4] - 2026-10-22

### Added
- Transparent 32-bit RGBA application icon with native macOS squircle drop shadow

### Changed
- Standardized product branding to FetchFlow across all documentation, menus, and release packages
- Configured `CFBundleDisplayName` so macOS displays "FetchFlow" in Dock, Menu Bar, and App Switcher

## [1.0.3] - 2026-10-22

### Fixed
- Port input no longer attempts privileged ports (< 1024) or partially typed ports; engine settings are debounced.
- Torrents with every file deselected now display **No Files Selected** / 0% instead of a completed download.
- Release builds derive a monotonic build number from the marketing version.
- Release workflow refuses to publish an unsigned appcast when `SPARKLE_PRIVATE_KEY` is missing.

### Changed
- Bandwidth settings explain that limits are session-wide targets and local-network peers are exempt by default.
- Local release staging only indexes the archive being released.

## [1.0.2] - 2026-10-21

### Added
- Dynamic filter pill with funnel icon in toolbar

### Changed
- Bumped version to 1.0.2

## [1.0.1] - 2026-10-21

### Fixed
- Use native `Picker` for download filter dropdown in toolbar

### Added
- Pre-flight bundle verification gate script
- CI runner updated to macOS 26 for modern SDK support

## [1.0.0] - 2026-10-18

### Added
- Initial release
- Magnet link and `.torrent` file support
- Selective file downloading with full file hierarchy view
- Real-time download/upload speed gauges
- Progress percentages, ETA calculations, and seed/peer counts
- Category filters: All Downloads, Downloading, Completed, Paused, Active
- Pause, resume, and remove torrent controls
- Finder integration — reveal completed files in one click
- Hardened macOS App Sandbox
- Self-contained executable with statically linked libtorrent, Boost, and OpenSSL
- Sparkle auto-update integration
- GitHub Actions release pipeline with DMG packaging

[1.0.4]: https://github.com/lazydev17/FetchFlow/releases/tag/v1.0.4
[1.0.3]: https://github.com/lazydev17/FetchFlow/releases/tag/v1.0.3
[1.0.2]: https://github.com/lazydev17/FetchFlow/releases/tag/v1.0.2
[1.0.1]: https://github.com/lazydev17/FetchFlow/releases/tag/v1.0.1
[1.0.0]: https://github.com/lazydev17/FetchFlow/releases/tag/v1.0.0
