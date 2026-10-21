# Contributing to FetchFlow

Thank you for your interest in contributing! This guide will help you get started.

## Getting Started

### Prerequisites

- **macOS 15.6** (Sequoia) or later
- **Apple Silicon** Mac (arm64)
- **Xcode 16.0+**

### Building the Project

1. Clone the repository:
   ```bash
   git clone https://github.com/lazydev17/TorrentClient.git
   cd TorrentClient
   ```

2. Open in Xcode:
   ```bash
   open TorrentClient.xcodeproj
   ```

3. Select the **TorrentClient** scheme and press **⌘R** to build and run.

All dependencies (libtorrent, Boost, OpenSSL, Sparkle) are vendored in `Libraries/` — no Homebrew or external package managers needed.

### Building from the Terminal

```bash
xcodebuild \
  -project TorrentClient.xcodeproj \
  -scheme TorrentClient \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

## How to Contribute

### Reporting Bugs

- Use [GitHub Issues](https://github.com/lazydev17/TorrentClient/issues) with the **Bug Report** template
- Include your macOS version, app version, and steps to reproduce
- Attach Console.app logs if relevant

### Suggesting Features

- Open a [Feature Request](https://github.com/lazydev17/TorrentClient/issues) issue
- Describe the problem you're trying to solve, not just the solution

### Pull Requests

1. **Fork** the repository and create a branch from `main`
2. Make your changes in a focused, single-purpose branch
3. Test your changes locally — ensure the app builds and runs correctly
4. Submit a **Pull Request** against `main`

#### PR Guidelines

- Keep changes small and focused — one feature or fix per PR
- Write clear commit messages: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`
- Preserve existing comments and documentation unless your change requires updating them
- Follow the existing code style (SwiftUI, `@MainActor`, `ObservableObject` patterns)

## Code Style

- **SwiftUI** for all views — no UIKit/AppKit views unless wrapping native controls
- **`@MainActor`** on all `ObservableObject` controllers
- Use `async`/`await` for asynchronous work
- Prefer Swift's native types and protocols
- Keep views small and composable

## Project Structure

```
TorrentClient/
├── Libraries/               # Vendored C++ dependencies (do not modify)
├── TorrentClient/           # Application source code
│   ├── *App.swift           # App lifecycle
│   ├── *View.swift          # SwiftUI views
│   ├── Models.swift         # Data models
│   ├── TorrentManager.swift # Core session controller
│   ├── TorrentWrapper.*     # Obj-C++ bridge to libtorrent
│   └── methods/             # Helper functions
├── scripts/                 # Build & release tooling
└── .github/workflows/       # CI/CD
```

> **Note:** The `Libraries/` directory contains precompiled static libraries. Do not modify these files. If you need to update a dependency, open an issue to discuss it first.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
