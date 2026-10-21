# Changelog

All notable changes to TorrentClient (FetchFlow) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

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

[1.0.2]: https://github.com/lazydev17/TorrentClient/releases/tag/v1.0.2
[1.0.1]: https://github.com/lazydev17/TorrentClient/releases/tag/v1.0.1
[1.0.0]: https://github.com/lazydev17/TorrentClient/releases/tag/v1.0.0
