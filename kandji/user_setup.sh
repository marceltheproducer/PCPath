#!/bin/bash
# PCPath per-user setup — runs at login via LaunchAgent
# Copies workflows and scripts into the current user's home directory.

set -e

SYSTEM_DIR="/usr/local/pcpath"
INSTALL_DIR="$HOME/.pcpath"
SERVICES_DIR="$HOME/Library/Services"
CONFIG_FILE="$HOME/.pcpath_mappings"
STAMP_FILE="$INSTALL_DIR/.installed_version"

# Determine installed version from the system directory
VERSION_FILE="$SYSTEM_DIR/.version"
INSTALLED_VERSION=""
[[ -f "$STAMP_FILE" ]] && INSTALLED_VERSION=$(cat "$STAMP_FILE" 2>/dev/null)
CURRENT_VERSION=""
[[ -f "$VERSION_FILE" ]] && CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null)

# Skip if already set up for this version
if [[ -n "$CURRENT_VERSION" && "$INSTALLED_VERSION" == "$CURRENT_VERSION" ]]; then
    exit 0
fi

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$SERVICES_DIR"

# Copy scripts
cp "$SYSTEM_DIR/pcpath_common.sh" "$INSTALL_DIR/"
cp "$SYSTEM_DIR/copy_pc_path.sh" "$INSTALL_DIR/"
cp "$SYSTEM_DIR/paste_mac_path.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/pcpath_common.sh"
chmod +x "$INSTALL_DIR/copy_pc_path.sh"
chmod +x "$INSTALL_DIR/paste_mac_path.sh"

# Install workflows
cp -R "$SYSTEM_DIR/Copy as PC Path.workflow" "$SERVICES_DIR/"
cp -R "$SYSTEM_DIR/Convert to Mac Path.workflow" "$SERVICES_DIR/"

# Create default config if it doesn't exist
if [[ ! -f "$CONFIG_FILE" ]]; then
    cp "$SYSTEM_DIR/pcpath_mappings.default" "$CONFIG_FILE"
fi

# Stamp the installed version so we don't repeat on every login
if [[ -n "$CURRENT_VERSION" ]]; then
    echo "$CURRENT_VERSION" > "$STAMP_FILE"
fi
