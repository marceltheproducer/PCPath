#!/bin/bash
# build_pkg.sh — Builds a macOS .pkg installer for Kandji (or any MDM) deployment.
#
# Usage:
#   ./kandji/build_pkg.sh [version]                    # unsigned (for testing)
#   ./kandji/build_pkg.sh [version] --sign             # signed, notarized, stapled
#
# Examples:
#   ./kandji/build_pkg.sh                              # unsigned PCPath-1.0.0.pkg
#   ./kandji/build_pkg.sh 1.2.0 --sign                 # signed + notarized PCPath-1.2.0.pkg
#
# Environment variables (required when using --sign):
#   DEVELOPER_ID_APP          Developer ID Application certificate name
#                             e.g. "Developer ID Application: Your Name (TEAMID)"
#   DEVELOPER_ID_INSTALLER    Developer ID Installer certificate name
#                             e.g. "Developer ID Installer: Your Name (TEAMID)"
#   NOTARY_PROFILE            Keychain profile for notarytool (see setup below)
#
# One-time notarytool setup:
#   xcrun notarytool store-credentials "PCPath" \
#     --apple-id "you@example.com" \
#     --team-id "ABCDE12345" \
#     --password "app-specific-password"
#   Then set NOTARY_PROFILE="PCPath"
#
# The resulting .pkg can be uploaded directly to Kandji as a Custom App.

set -e

VERSION="${1:-1.0.0}"
SIGN=false
if [[ "$2" == "--sign" ]]; then
    SIGN=true
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
PAYLOAD_DIR="$BUILD_DIR/payload/usr/local/pcpath"
SCRIPTS_DIR="$BUILD_DIR/scripts"
PKG_NAME="PCPath-${VERSION}.pkg"
PKG_UNSIGNED="PCPath-${VERSION}-unsigned.pkg"
PKG_ID="com.pcpath.pkg"
ENTITLEMENTS="$SCRIPT_DIR/entitlements.plist"

# --- Validate signing prerequisites ---
if $SIGN; then
    missing=""
    [[ -z "$DEVELOPER_ID_APP" ]] && missing="$missing DEVELOPER_ID_APP"
    [[ -z "$DEVELOPER_ID_INSTALLER" ]] && missing="$missing DEVELOPER_ID_INSTALLER"
    [[ -z "$NOTARY_PROFILE" ]] && missing="$missing NOTARY_PROFILE"
    if [[ -n "$missing" ]]; then
        echo "ERROR: --sign requires these environment variables:$missing"
        echo ""
        echo "Example:"
        echo '  export DEVELOPER_ID_APP="Developer ID Application: Your Name (TEAMID)"'
        echo '  export DEVELOPER_ID_INSTALLER="Developer ID Installer: Your Name (TEAMID)"'
        echo '  export NOTARY_PROFILE="PCPath"'
        exit 1
    fi
    echo "Building PCPath ${VERSION} installer (signed)..."
else
    echo "Building PCPath ${VERSION} installer (unsigned — for testing only)..."
fi

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$PAYLOAD_DIR"
mkdir -p "$SCRIPTS_DIR"

# --- Payload: files installed to /usr/local/pcpath/ ---

# Core scripts
cp "$REPO_DIR/pcpath_common.sh" "$PAYLOAD_DIR/"
cp "$REPO_DIR/copy_pc_path.sh" "$PAYLOAD_DIR/"
cp "$REPO_DIR/paste_mac_path.sh" "$PAYLOAD_DIR/"

# Default config template
cp "$REPO_DIR/pcpath_mappings.default" "$PAYLOAD_DIR/"

# Automator workflows
cp -R "$REPO_DIR/Copy as PC Path.workflow" "$PAYLOAD_DIR/"
cp -R "$REPO_DIR/Convert to Mac Path.workflow" "$PAYLOAD_DIR/"

# Per-user setup script and LaunchAgent plist
cp "$SCRIPT_DIR/user_setup.sh" "$PAYLOAD_DIR/"
cp "$SCRIPT_DIR/com.pcpath.user-setup.plist" "$PAYLOAD_DIR/"

# Version stamp (used by user_setup.sh to skip re-setup)
echo "$VERSION" > "$PAYLOAD_DIR/.version"

# Make scripts executable
chmod +x "$PAYLOAD_DIR/pcpath_common.sh"
chmod +x "$PAYLOAD_DIR/copy_pc_path.sh"
chmod +x "$PAYLOAD_DIR/paste_mac_path.sh"
chmod +x "$PAYLOAD_DIR/user_setup.sh"

# --- Code-sign Automator workflows (hardened runtime + entitlements) ---
if $SIGN; then
    echo "Signing Automator workflows..."
    codesign --force --options runtime --deep --timestamp \
        --sign "$DEVELOPER_ID_APP" \
        --entitlements "$ENTITLEMENTS" \
        "$PAYLOAD_DIR/Copy as PC Path.workflow"

    codesign --force --options runtime --deep --timestamp \
        --sign "$DEVELOPER_ID_APP" \
        --entitlements "$ENTITLEMENTS" \
        "$PAYLOAD_DIR/Convert to Mac Path.workflow"

    echo "Workflows signed."
fi

# --- Installer scripts ---
cp "$SCRIPT_DIR/postinstall" "$SCRIPTS_DIR/postinstall"
chmod +x "$SCRIPTS_DIR/postinstall"

# --- Build the .pkg ---
if $SIGN; then
    # Build unsigned first, then sign with productsign
    pkgbuild \
        --root "$BUILD_DIR/payload" \
        --scripts "$SCRIPTS_DIR" \
        --identifier "$PKG_ID" \
        --version "$VERSION" \
        --install-location "/" \
        "$SCRIPT_DIR/$PKG_UNSIGNED"

    echo "Signing package with Developer ID Installer..."
    productsign \
        --sign "$DEVELOPER_ID_INSTALLER" \
        --timestamp \
        "$SCRIPT_DIR/$PKG_UNSIGNED" \
        "$SCRIPT_DIR/$PKG_NAME"

    rm -f "$SCRIPT_DIR/$PKG_UNSIGNED"
    echo "Package signed."

    # --- Verify signature ---
    echo "Verifying signature..."
    pkgutil --check-signature "$SCRIPT_DIR/$PKG_NAME"

    # --- Notarize ---
    echo "Submitting to Apple for notarization (this may take a few minutes)..."
    xcrun notarytool submit "$SCRIPT_DIR/$PKG_NAME" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait

    # --- Staple ---
    echo "Stapling notarization ticket..."
    xcrun stapler staple "$SCRIPT_DIR/$PKG_NAME"
    xcrun stapler validate "$SCRIPT_DIR/$PKG_NAME"
    echo "Notarization complete."
else
    pkgbuild \
        --root "$BUILD_DIR/payload" \
        --scripts "$SCRIPTS_DIR" \
        --identifier "$PKG_ID" \
        --version "$VERSION" \
        --install-location "/" \
        "$SCRIPT_DIR/$PKG_NAME"
fi

# Clean up build artifacts
rm -rf "$BUILD_DIR"

echo ""
echo "Package built: kandji/$PKG_NAME"
if $SIGN; then
    echo "  Status: Signed, notarized, and stapled — ready for distribution."
else
    echo "  Status: UNSIGNED — for local testing only. Use --sign for distribution."
fi
echo ""
echo "To deploy via Kandji:"
echo "  1. Go to Kandji > Library > Add New > Custom App"
echo "  2. Set install type to 'Package'"
echo "  3. Upload $PKG_NAME"
echo "  4. (Optional) Add an uninstall script — see kandji/uninstall_mdm.sh"
echo ""
echo "To push a company-wide config, also deploy ~/.pcpath_mappings"
echo "via a Kandji Custom Script (see README)."
