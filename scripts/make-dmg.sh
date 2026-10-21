#!/usr/bin/env bash
#
# make-dmg.sh - Creates a macOS distribution disk image (DMG) for TorrentClient.
#
# Packages TorrentClient.app into a compressed, read-only DMG with an /Applications
# shortcut link and generates a SHA-256 checksum file.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_NAME="TorrentClient"
VOL_NAME="FetchFlow"

# Input .app path (default: release build from DerivedData or argument)
APP_PATH="${1:-}"
if [ -z "$APP_PATH" ]; then
    DEFAULT_APP="${PROJECT_DIR}/build/DerivedData/Build/Products/Release/${APP_NAME}.app"
    if [ -d "$DEFAULT_APP" ]; then
        APP_PATH="$DEFAULT_APP"
    else
        APP_PATH="$(find ~/Library/Developer/Xcode/DerivedData -path "*/Build/Products/Release/${APP_NAME}.app" -type d 2>/dev/null | head -n 1)"
    fi
fi

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "ERROR: ${APP_NAME}.app not found. Build the Release scheme first."
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${APP_PATH}/Contents/Info.plist" 2>/dev/null || echo "1.0.1")"
DIST_DIR="${PROJECT_DIR}/releases"
mkdir -p "$DIST_DIR"

DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"

echo "Creating disk image: ${DMG_NAME} from ${APP_PATH}..."

# Setup staging directory
STAGE_DIR="$(mktemp -d -t "dmg_stage_${APP_NAME}")"
trap 'rm -rf "$STAGE_DIR" 2>/dev/null || true' EXIT

# Copy application bundle preserving symlinks and metadata
ditto "$APP_PATH" "${STAGE_DIR}/${APP_NAME}.app"

# Create /Applications shortcut
ln -s /Applications "${STAGE_DIR}/Applications"

# Include open-source license notices in the distributed disk image.
for doc in LICENSE THIRD_PARTY_LICENSES README.md; do
    if [ -f "${PROJECT_DIR}/${doc}" ]; then
        cp "${PROJECT_DIR}/${doc}" "${STAGE_DIR}/${doc}"
    fi
done

# Set volume icon if AppIcon.icns exists
ICON_SRC="${PROJECT_DIR}/Resources/AppIcon.icns"
if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "${STAGE_DIR}/.VolumeIcon.icns"
fi

# Remove any existing output DMG
rm -f "$DMG_PATH"

# Build compressed, read-only DMG (UDZO)
hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$STAGE_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH" > /dev/null

# Compute SHA-256 checksum
(cd "$DIST_DIR" && shasum -a 256 "$DMG_NAME" > "${DMG_NAME}.sha256")

echo "DMG successfully built: ${DMG_PATH}"
echo "SHA-256: $(cat "${DMG_PATH}.sha256")"
