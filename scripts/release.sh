#!/usr/bin/env bash
#
# release.sh - Builds, packages, signs, and generates Sparkle appcast for TorrentClient
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
RELEASES_DIR="$REPO_ROOT/releases"

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

echo "=== TorrentClient Sparkle Release Builder ==="

# 1. Determine version
VERSION="${1:-1.0.0}"
echo "Building Release version: $VERSION"

# 2. Build Release configuration
echo "Compiling Release build with xcodebuild..."
cd "$REPO_ROOT"
xcodebuild clean build \
    -project TorrentClient.xcodeproj \
    -scheme TorrentClient \
    -configuration Release \
    -derivedDataPath "$REPO_ROOT/build/DerivedData" \
    MARKETING_VERSION="$VERSION" \
    > /dev/null

APP_PATH="$REPO_ROOT/build/DerivedData/Build/Products/Release/TorrentClient.app"
if [ ! -d "$APP_PATH" ]; then
    echo "Error: Release build not found at $APP_PATH"
    exit 1
fi
echo "✓ Release build completed: $APP_PATH"

# 3. Package archive
mkdir -p "$RELEASES_DIR"
ZIP_NAME="TorrentClient-$VERSION.zip"
ZIP_PATH="$RELEASES_DIR/$ZIP_NAME"

echo "Creating distribution zip: $ZIP_NAME..."
rm -f "$ZIP_PATH"
# Using ditto preserves macOS resource forks, symlinks, and code signature
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
echo "✓ Distribution zip created ($(du -sh "$ZIP_PATH" | awk '{print $1}'))"

# 4. Sign update and generate appcast.xml
echo "Generating Sparkle EdDSA signature and appcast feed..."
"$BIN_DIR/generate_appcast" \
    --account TorrentClient \
    --download-url-prefix "https://github.com/satya-sanjay2110/TorrentClient/releases/download/v$VERSION/" \
    "$RELEASES_DIR"

if [ -f "$RELEASES_DIR/appcast.xml" ]; then
    cp "$RELEASES_DIR/appcast.xml" "$REPO_ROOT/appcast.xml"
    if [ -d "$REPO_ROOT/../TorrentClient" ] && [ -f "$REPO_ROOT/../appcast.xml" ]; then
        cp "$RELEASES_DIR/appcast.xml" "$REPO_ROOT/../appcast.xml"
    fi
    echo "✓ appcast.xml updated and signed successfully!"
fi

echo ""
echo "=== Release $VERSION Ready for Distribution! ==="
echo "Artifact: $ZIP_PATH"
echo "Feed:     $REPO_ROOT/appcast.xml"
echo ""
echo "Next steps to publish to users across all devices:"
echo "1. Create GitHub Release:"
echo "   gh release create v$VERSION \"$ZIP_PATH\" --title \"TorrentClient v$VERSION\" --notes \"Release $VERSION\""
echo "2. Push updated appcast.xml to GitHub:"
echo "   git add appcast.xml && git commit -m \"chore: update appcast.xml for v$VERSION\" && git push"
