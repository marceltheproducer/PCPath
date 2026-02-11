#!/bin/bash
# PCPath Uninstaller for macOS

INSTALL_DIR="$HOME/.pcpath"
SERVICES_DIR="$HOME/Library/Services"
CONFIG_FILE="$HOME/.pcpath_mappings"

echo "Uninstalling PCPath..."

rm -rf "$SERVICES_DIR/Copy as PC Path.workflow"
rm -rf "$SERVICES_DIR/Convert to Mac Path.workflow"
rm -rf "$INSTALL_DIR"

echo ""
echo "PCPath has been uninstalled."
echo "Config file kept at $CONFIG_FILE (delete manually if not needed)."
