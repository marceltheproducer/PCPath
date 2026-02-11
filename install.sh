#!/bin/bash
# PCPath Installer for macOS
# Installs Quick Actions and sets up the config file.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.pcpath"
SERVICES_DIR="$HOME/Library/Services"
CONFIG_FILE="$HOME/.pcpath_mappings"

echo "Installing PCPath..."
echo ""

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$SERVICES_DIR"

# Copy scripts
cp "$SCRIPT_DIR/pcpath_common.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/copy_pc_path.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/paste_mac_path.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/pcpath_common.sh"
chmod +x "$INSTALL_DIR/copy_pc_path.sh"
chmod +x "$INSTALL_DIR/paste_mac_path.sh"

# Create default config if it doesn't exist
if [[ ! -f "$CONFIG_FILE" ]]; then
    cp "$SCRIPT_DIR/pcpath_mappings.default" "$CONFIG_FILE"
    echo "  Created config file at $CONFIG_FILE"
else
    echo "  Config file already exists at $CONFIG_FILE (keeping existing)"
fi

# Install workflows
cp -R "$SCRIPT_DIR/Copy as PC Path.workflow" "$SERVICES_DIR/"
cp -R "$SCRIPT_DIR/Convert to Mac Path.workflow" "$SERVICES_DIR/"

echo "  Installed scripts to $INSTALL_DIR"
echo "  Installed Quick Actions to $SERVICES_DIR"
echo ""
echo "PCPath installed successfully!"
echo ""
echo "Quick Actions available:"
echo "  Copy as PC Path      Right-click a file in Finder > Quick Actions"
echo "  Convert to Mac Path  Select a PC path in any app > right-click > Services"
echo ""
echo "Drive mappings: $CONFIG_FILE"
echo "Edit that file to add or change volume-to-drive-letter mappings."
