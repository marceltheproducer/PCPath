#!/bin/bash
# build_pkg.sh — Builds a macOS .pkg installer for Kandji (or any MDM) deployment.
#
# Usage:
#   ./kandji/build_pkg.sh [version]
#
# Examples:
#   ./kandji/build_pkg.sh            # builds PCPath-1.0.0.pkg
#   ./kandji/build_pkg.sh 1.2.0      # builds PCPath-1.2.0.pkg
#
# The resulting .pkg can be uploaded directly to Kandji as a Custom App.

set -e

VERSION="${1:-1.0.0}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
PAYLOAD_DIR="$BUILD_DIR/payload/usr/local/pcpath"
SCRIPTS_DIR="$BUILD_DIR/scripts"
PKG_NAME="PCPath-${VERSION}.pkg"
PKG_ID="com.pcpath.pkg"

echo "Building PCPath ${VERSION} installer..."

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

# --- Installer scripts ---
cp "$SCRIPT_DIR/postinstall" "$SCRIPTS_DIR/postinstall"
chmod +x "$SCRIPTS_DIR/postinstall"

# --- Build the .pkg ---
pkgbuild \
    --root "$BUILD_DIR/payload" \
    --scripts "$SCRIPTS_DIR" \
    --identifier "$PKG_ID" \
    --version "$VERSION" \
    --install-location "/" \
    "$SCRIPT_DIR/$PKG_NAME"

# Clean up build artifacts
rm -rf "$BUILD_DIR"

echo ""
echo "Package built: kandji/$PKG_NAME"
echo ""
echo "To deploy via Kandji:"
echo "  1. Go to Kandji > Library > Add New > Custom App"
echo "  2. Set install type to 'Package'"
echo "  3. Upload $PKG_NAME"
echo "  4. (Optional) Add an uninstall script — see kandji/uninstall_mdm.sh"
echo ""
echo "To push a company-wide config, also deploy ~/.pcpath_mappings"
echo "via a Kandji Custom Script (see README)."
