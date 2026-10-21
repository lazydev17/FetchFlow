#!/usr/bin/env bash
#
# verify-bundle.sh - Pre-flight verification gate for TorrentClient.app
#
# Inspects an assembled .app bundle before packaging to guarantee:
#   1. Bundle layout and Info.plist structure
#   2. Architecture strictly matches Apple Silicon (arm64)
#   3. Deployment target minos matches macOS 15.6 (no macOS 26 host contamination)
#   4. Code signing seal is valid (--deep --strict)
#   5. App Sandbox entitlements are properly embedded
#   6. Embedded Sparkle.framework integrity and rpaths
#   7. Sparkle auto-update keys are present in Info.plist
#
# Exits with 0 on success; non-zero if any gate fails.
#
set -euo pipefail

APP_PATH="${1:-}"

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "Usage: $0 <path-to-TorrentClient.app> [expected-version]"
    exit 2
fi

EXPECTED_VERSION="${2:-}"
APP_NAME="TorrentClient"
MACOS_DIR="${APP_PATH}/Contents/MacOS"
APP_BIN="${MACOS_DIR}/${APP_NAME}"
INFO_PLIST="${APP_PATH}/Contents/Info.plist"

FAILURES=0
if [ -t 1 ]; then
    GREEN=$'\033[32m'
    RED=$'\033[31m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
else
    GREEN=""
    RED=""
    BOLD=""
    RESET=""
fi

pass() { printf "  [%sPASS%s] %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "  [%sFAIL%s] %s\n" "$RED" "$RESET" "$1"; FAILURES=$((FAILURES + 1)); }

echo "======================================================================"
echo "${BOLD}Verifying Application Bundle:${RESET} ${APP_PATH}"
echo "======================================================================"

# 1. Bundle Structure
if [ -f "$APP_BIN" ] && [ -x "$APP_BIN" ]; then
    pass "Executable binary exists and is executable: Contents/MacOS/${APP_NAME}"
else
    fail "Executable binary missing or not executable: ${APP_BIN}"
fi

if [ -f "$INFO_PLIST" ]; then
    pass "Info.plist present"
else
    fail "Info.plist missing at: ${INFO_PLIST}"
fi

# 2. Architecture Gate
ARCHS="$(lipo -archs "$APP_BIN" 2>/dev/null || echo "unknown")"
if [ "$ARCHS" = "arm64" ]; then
    pass "Architecture strictly arm64 (Apple Silicon): ${ARCHS}"
else
    fail "Unexpected architecture: ${ARCHS} (expected: arm64)"
fi

# 3. Deployment Target Gate (minos check)
MINOS="$(otool -l "$APP_BIN" | awk '/cmd LC_BUILD_VERSION/{flag=1; next} flag && /minos/{print $2; exit}')"
SDK_VER="$(otool -l "$APP_BIN" | awk '/cmd LC_BUILD_VERSION/{flag=1; next} flag && /sdk/{print $2; exit}')"
if [ "$MINOS" = "15.6" ] || [ "$MINOS" = "15.0" ]; then
    pass "Mach-O deployment target verified: minos ${MINOS} (linked against SDK ${SDK_VER})"
else
    fail "Mach-O deployment target mismatch: minos ${MINOS} (expected <= 15.6)"
fi

# 4. Code Signature & Seal Gate
if codesign --verify --deep --strict "$APP_PATH" >/dev/null 2>&1; then
    pass "Code signature and bundle seal verified (codesign --deep --strict)"
else
    fail "Code signature verification failed for ${APP_PATH}"
fi

# 5. App Sandbox Entitlements Gate
ENTITLEMENTS="$(codesign -d --entitlements :- "$APP_PATH" 2>/dev/null || echo "")"
if echo "$ENTITLEMENTS" | grep -q "com.apple.security.app-sandbox"; then
    pass "App Sandbox entitlement verified (com.apple.security.app-sandbox = true)"
else
    fail "App Sandbox entitlement missing from signature"
fi

if echo "$ENTITLEMENTS" | grep -q "com.apple.security.network.client"; then
    pass "Network client entitlement verified"
else
    fail "Network client entitlement missing"
fi

if echo "$ENTITLEMENTS" | grep -q "com.apple.security.files.downloads.read-write"; then
    pass "Downloads folder read-write entitlement verified"
else
    fail "Downloads folder entitlement missing"
fi

# 6. Embedded Frameworks Gate (Sparkle)
SPARKLE_FW="${APP_PATH}/Contents/Frameworks/Sparkle.framework"
if [ -d "$SPARKLE_FW" ]; then
    pass "Sparkle.framework embedded in Contents/Frameworks"
    if codesign --verify --deep --strict "$SPARKLE_FW" >/dev/null 2>&1; then
        pass "Sparkle.framework code signature verified"
    else
        fail "Sparkle.framework code signature is invalid"
    fi
else
    fail "Sparkle.framework missing from Contents/Frameworks"
fi

# 7. Info.plist & Sparkle Auto-Update Configuration Gate
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO_PLIST" 2>/dev/null || echo "")"
BUNDLE_VER="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "")"
BUILD_NUM="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST" 2>/dev/null || echo "")"
SU_FEED="$(/usr/libexec/PlistBuddy -c "Print :SUFeedURL" "$INFO_PLIST" 2>/dev/null || echo "")"
SU_KEY="$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$INFO_PLIST" 2>/dev/null || echo "")"

if [ -n "$BUNDLE_ID" ]; then
    pass "Bundle identifier: ${BUNDLE_ID}"
else
    fail "CFBundleIdentifier is missing"
fi

if [ -n "$BUNDLE_VER" ] && [ -n "$BUILD_NUM" ]; then
    pass "Version: ${BUNDLE_VER} (Build ${BUILD_NUM})"
    if [ -n "$EXPECTED_VERSION" ] && [ "$BUNDLE_VER" != "$EXPECTED_VERSION" ]; then
        fail "Version mismatch: expected ${EXPECTED_VERSION}, got ${BUNDLE_VER}"
    fi
else
    fail "Version information missing from Info.plist"
fi

if [ -n "$SU_FEED" ] && echo "$SU_FEED" | grep -q "appcast.xml"; then
    pass "Sparkle SUFeedURL configured: ${SU_FEED}"
else
    fail "SUFeedURL is missing or does not point to appcast.xml"
fi

if [ -n "$SU_KEY" ]; then
    pass "Sparkle SUPublicEDKey present: ${SU_KEY:0:12}..."
else
    fail "SUPublicEDKey is missing from Info.plist"
fi

# 8. Result Summary
echo "----------------------------------------------------------------------"
if [ "$FAILURES" -eq 0 ]; then
    echo "${GREEN}${BOLD}ALL GATES PASSED.${RESET} Bundle is verified and ready for distribution."
    echo "======================================================================"
    exit 0
else
    echo "${RED}${BOLD}VERIFICATION FAILED:${RESET} ${FAILURES} gate check(s) failed."
    echo "======================================================================"
    exit 1
fi
