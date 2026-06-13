#!/bin/bash
# build.sh — Build, sign, notarize & staple the PCPath.app (with embedded
# Finder Sync extension). Run on a Mac that has Xcode + a Developer ID cert.
#
# Usage:
#   ./build.sh [version]            # build only (must be signed to load on another Mac)
#   ./build.sh 1.0.0 --notarize     # build + notarize + staple
#
# Required env when signing/notarizing:
#   DEVELOPER_ID_APP   e.g. "Developer ID Application: Your Co (TEAMID)"
#   TEAM_ID            e.g. "ABCDE12345"
#   NOTARY_PROFILE     keychain profile for notarytool (see one-time setup below)
#
# One-time notarytool setup:
#   xcrun notarytool store-credentials "PCPath" \
#     --apple-id "you@example.com" --team-id "ABCDE12345" \
#     --password "app-specific-password"
#   export NOTARY_PROFILE=PCPath
#
# Prereqs:  brew install xcodegen   (and full Xcode, not just Command Line Tools)

set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-1.0.0}"
NOTARIZE=false
[[ "${2:-}" == "--notarize" ]] && NOTARIZE=true

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: version must be semver (e.g. 1.0.0)" >&2; exit 1
fi

# --- preflight ---
command -v xcodegen >/dev/null || { echo "ERROR: xcodegen not found (brew install xcodegen)" >&2; exit 1; }
if ! xcodebuild -version >/dev/null 2>&1; then
    echo "ERROR: full Xcode required (xcode-select -s /Applications/Xcode.app)" >&2; exit 1
fi

SIGN_ARGS=()
if [[ -n "${DEVELOPER_ID_APP:-}" ]]; then
    : "${TEAM_ID:?Set TEAM_ID when signing}"
    SIGN_ARGS=(
        CODE_SIGN_IDENTITY="$DEVELOPER_ID_APP"
        DEVELOPMENT_TEAM="$TEAM_ID"
        CODE_SIGN_STYLE=Manual
        OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime"
    )
    echo "Signing as: $DEVELOPER_ID_APP"
else
    echo "WARNING: DEVELOPER_ID_APP not set — building UNSIGNED (won't load on other Macs)."
    SIGN_ARGS=(CODE_SIGNING_ALLOWED=NO)
fi

echo "==> Generating Xcode project (xcodegen)"
xcodegen generate

echo "==> Building PCPath.app ($VERSION)"
rm -rf build dist
xcodebuild \
    -project PCPath.xcodeproj \
    -scheme PCPath \
    -configuration Release \
    -derivedDataPath build \
    MARKETING_VERSION="$VERSION" \
    "${SIGN_ARGS[@]}" \
    clean build | tail -20

APP="build/Build/Products/Release/PCPath.app"
[[ -d "$APP" ]] || { echo "ERROR: build produced no app at $APP" >&2; exit 1; }

mkdir -p dist
cp -R "$APP" dist/
APP="dist/PCPath.app"

echo "==> Verifying code signature"
codesign --verify --deep --strict --verbose=2 "$APP" || echo "(unsigned build — skipping strict verify)"
echo "Embedded extension:"; ls "$APP/Contents/PlugIns/" 2>/dev/null || echo "  (none — check embed)"

if $NOTARIZE; then
    : "${NOTARY_PROFILE:?Set NOTARY_PROFILE to notarize}"
    echo "==> Notarizing"
    ZIP="dist/PCPath-$VERSION.zip"
    /usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    echo "==> Stapling"
    xcrun stapler staple "$APP"
    xcrun stapler validate "$APP"
    rm -f "$ZIP"
fi

echo ""
echo "OK  Built $APP  (version $VERSION)"
echo "Next: package for MDM with  kandji/build_app_pkg.sh $VERSION"
