#!/usr/bin/env bash
#
# release.sh - Complete local release orchestrator for TorrentClient (FetchFlow).
#
# Pipeline:
#   1. Clean Release build for Apple Silicon (arm64)
#   2. Package TorrentClient-<version>.dmg with /Applications link & .sha256
#   3. Package TorrentClient-<version>.zip for Sparkle auto-updates & .sha256
#   4. Sign and update appcast.xml using vendored Sparkle tools & EdDSA private key
#   5. Output formatted GitHub Release notes with Gatekeeper instructions & checksums
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_NAME="TorrentClient"

cd "$PROJECT_DIR"

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------
SPARKLE_BIN="${PROJECT_DIR}/scripts/bin/generate_appcast"
SPARKLE_KEY="${PROJECT_DIR}/.sparkle/sparkle_priv.key"

if [ ! -x "$SPARKLE_BIN" ]; then
    echo "ERROR: Sparkle generate_appcast tool not found or not executable at: $SPARKLE_BIN"
    exit 1
fi

if [ ! -f "$SPARKLE_KEY" ]; then
    echo "ERROR: Sparkle private key not found at: $SPARKLE_KEY"
    exit 1
fi

# Determine Version & Build
VERSION="$(grep -m 1 "MARKETING_VERSION" "${PROJECT_DIR}/${APP_NAME}.xcodeproj/project.pbxproj" | awk -F '=' '{print $2}' | tr -d ' ;"')"
VERSION="${1:-$VERSION}"
VERSION="${VERSION#v}"
TAG="v${VERSION}"

# Keep Sparkle's CFBundleVersion monotonically increasing and tied to the
# marketing version (1.2.3 -> 10203). This avoids shipping a new tag with a
# stale build number, which Sparkle would ignore.
IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"
PATCH="${PATCH%%-*}"
BUILD_NUMBER=$((10#${MAJOR:-0} * 10000 + 10#${MINOR:-0} * 100 + 10#${PATCH:-0}))

echo "======================================================================"
echo " Preparing Release: ${APP_NAME} ${VERSION} (Build ${BUILD_NUMBER}) [${TAG}]"
echo " Target Architecture: Apple Silicon (arm64)"
echo "======================================================================"

BUILD_OUTPUT="${PROJECT_DIR}/build/DerivedData"
APP_DIR="${BUILD_OUTPUT}/Build/Products/Release/${APP_NAME}.app"
DIST_DIR="${PROJECT_DIR}/releases"
mkdir -p "$DIST_DIR"

# ---------------------------------------------------------------------------
# 1. Build Release Scheme
# ---------------------------------------------------------------------------
echo ""
echo "--> Step 1: Building Release application..."

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild clean build \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_OUTPUT" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    ARCHS="arm64" \
    ONLY_ACTIVE_ARCH=YES \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_STYLE="Manual" \
    -quiet

if [ ! -d "$APP_DIR" ]; then
    echo "ERROR: Build failed; ${APP_DIR} does not exist."
    exit 1
fi
echo "    App successfully built at: ${APP_DIR}"

# ---------------------------------------------------------------------------
# Pre-Flight Verification Gate
# ---------------------------------------------------------------------------
echo ""
echo "--> Pre-Flight Gate: Validating application bundle..."
"${PROJECT_DIR}/scripts/verify-bundle.sh" "$APP_DIR" "$VERSION"

# ---------------------------------------------------------------------------
# 2. Package DMG (Installer for New Users)
# ---------------------------------------------------------------------------
echo ""
echo "--> Step 2: Packaging Distribution DMG..."
"${PROJECT_DIR}/scripts/make-dmg.sh" "$APP_DIR"
DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"

# ---------------------------------------------------------------------------
# 3. Package ZIP (Sparkle Updater Archive)
# ---------------------------------------------------------------------------
echo ""
echo "--> Step 3: Packaging Sparkle update ZIP archive..."
ZIP_NAME="${APP_NAME}-${VERSION}.zip"
ZIP_PATH="${DIST_DIR}/${ZIP_NAME}"
rm -f "$ZIP_PATH"

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"
(cd "$DIST_DIR" && shasum -a 256 "$ZIP_NAME" > "${ZIP_NAME}.sha256")

echo "    ZIP successfully packaged: ${ZIP_PATH}"
echo "    SHA-256: $(cat "${ZIP_PATH}.sha256")"

# ---------------------------------------------------------------------------
# 4. Generate & Sign Sparkle appcast.xml (Staging Directory)
# ---------------------------------------------------------------------------
echo ""
echo "--> Step 4: Signing and updating Sparkle appcast.xml..."
DOWNLOAD_URL_PREFIX="https://github.com/lazydev17/TorrentClient/releases/download/${TAG}/"

# Use dedicated staging directory so generate_appcast only indexes .zip archives
APPCAST_STAGING="$(mktemp -d -t "sparkle_stage_${APP_NAME}")"
trap 'rm -rf "$APPCAST_STAGING" 2>/dev/null || true' EXIT

# Only index the archive being released. Copying every historical zip would
# assign all of them the current tag's download URL in the generated appcast.
cp "$ZIP_PATH" "$APPCAST_STAGING/"
if [ -f "${PROJECT_DIR}/appcast.xml" ]; then
    cp "${PROJECT_DIR}/appcast.xml" "${APPCAST_STAGING}/appcast.xml"
fi

"$SPARKLE_BIN" \
    --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
    --ed-key-file "$SPARKLE_KEY" \
    --maximum-versions 0 \
    --maximum-deltas 0 \
    "$APPCAST_STAGING"

# Sync updated appcast.xml back
if [ -f "${APPCAST_STAGING}/appcast.xml" ]; then
    cp "${APPCAST_STAGING}/appcast.xml" "${DIST_DIR}/appcast.xml"
    cp "${APPCAST_STAGING}/appcast.xml" "${PROJECT_DIR}/appcast.xml"
    echo "    appcast.xml updated and cryptographically signed with EdDSA."
fi

# ---------------------------------------------------------------------------
# Summary & Release Notes
# ---------------------------------------------------------------------------
DMG_HASH="$(cat "${DMG_PATH}.sha256" | awk '{print $1}')"
ZIP_HASH="$(cat "${ZIP_PATH}.sha256" | awk '{print $1}')"

echo ""
echo "======================================================================"
echo " RELEASE ARTIFACTS READY:"
echo "======================================================================"
echo " DMG:     ${DMG_PATH}"
echo " ZIP:     ${ZIP_PATH}"
echo " APPCAST: ${PROJECT_DIR}/appcast.xml"
echo ""
echo "----------------------------------------------------------------------"
echo " SUGGESTED GITHUB RELEASE NOTES:"
echo "----------------------------------------------------------------------"
cat <<EOF
## FetchFlow (TorrentClient) ${TAG}

### What's New
- Native Apple Silicon (arm64) high-performance BitTorrent engine powered by libtorrent-rasterbar 2.0.11.
- Modern minimalist application icon and native macOS Sequoia/Tahoe design.
- In-app automatic updates via Sparkle with cryptographic Ed25519 verification.

### Installation
Choose your preferred download:
- **\`${APP_NAME}-${VERSION}.dmg\`**: Drag and drop \`${APP_NAME}.app\` into your Applications folder.
- **\`${APP_NAME}-${VERSION}.zip\`**: Archive used by the in-app automatic updater.

> **First Launch on macOS (Gatekeeper)**:
> This application is independently signed with Ed25519 cryptographic verification. On first open, macOS may state that the developer cannot be verified:
> 1. Open **System Settings → Privacy & Security**.
> 2. Scroll down to the security section for **${APP_NAME}**.
> 3. Click **Open Anyway** and confirm. (This is only required once).

### Integrity Checksums (SHA-256)
\`\`\`
${DMG_HASH}  ${APP_NAME}-${VERSION}.dmg
${ZIP_HASH}  ${APP_NAME}-${VERSION}.zip
\`\`\`
EOF
echo "======================================================================"
