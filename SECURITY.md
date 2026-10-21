# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | ✅ Yes             |

## Reporting a Vulnerability

If you discover a security vulnerability in TorrentClient (FetchFlow), **please do not open a public issue**.

Instead, please report it responsibly by contacting the maintainer directly through:

- **GitHub**: Send a private message via the [Security Advisories](https://github.com/lazydev17/TorrentClient/security/advisories) tab

### What to Include

- A description of the vulnerability
- Steps to reproduce the issue
- The potential impact
- Any suggested fixes (if you have them)

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 1 week
- **Fix & Disclosure**: Coordinated with the reporter

## Security Considerations

TorrentClient is a BitTorrent client that communicates over the network. Security-relevant areas include:

- **Network communications**: The app uses libtorrent-rasterbar for peer-to-peer connections
- **File system access**: Downloads are written to the user's Downloads folder via App Sandbox
- **Auto-updates**: Sparkle framework with EdDSA signature verification ensures update integrity
- **App Sandbox**: The app runs in a hardened sandbox with only necessary entitlements (network client/server, Downloads folder access)

## Dependencies

The app vendors precompiled versions of security-critical libraries. If a vulnerability is found in any of these, an updated build will be released:

- **OpenSSL** — TLS/cryptographic operations
- **libtorrent-rasterbar** — BitTorrent protocol implementation
- **Boost** — C++ utility library
- **Sparkle** — macOS auto-update framework
