#!/bin/bash
# PCPath Installer for macOS
# Installs Quick Actions and sets up the config file.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.pcpath"
SERVICES_DIR="$HOME/Library/Services"
CONFIG_FILE="$HOME/.pcpath_mappings"
LOG_FILE="$INSTALL_DIR/install.log"
STEP=0
TOTAL=4

_step() {
    STEP=$((STEP + 1))
    printf "  [%d/%d] %-35s" "$STEP" "$TOTAL" "$1"
}

echo "Installing PCPath..."
echo ""

_step "Creating install directory..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$SERVICES_DIR"
echo "done"

_step "Copying scripts..."
cp "$SCRIPT_DIR/pcpath_common.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/copy_pc_path.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/paste_mac_path.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/copy_names.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/pcpath_common.sh"
chmod +x "$INSTALL_DIR/copy_pc_path.sh"
chmod +x "$INSTALL_DIR/paste_mac_path.sh"
chmod +x "$INSTALL_DIR/copy_names.sh"
echo "done"

_step "Installing Quick Actions..."
WORKFLOWS=("Copy as PC Path" "Convert to Mac Path" "Copy Names")
for wf in "${WORKFLOWS[@]}"; do
    rm -rf "$SERVICES_DIR/$wf.workflow"
    cp -R "$SCRIPT_DIR/$wf.workflow" "$SERVICES_DIR/"
    # Strip quarantine/provenance so macOS doesn't silently suppress the
    # unsigned Quick Action when it was copied from an SMB share or download.
    xattr -dr com.apple.quarantine "$SERVICES_DIR/$wf.workflow" 2>/dev/null || true
    xattr -dr com.apple.provenance "$SERVICES_DIR/$wf.workflow" 2>/dev/null || true
done
# Rebuild the Services cache AND relaunch Finder. pbs -flush alone leaves the
# running Finder's context menu stale, which is why the actions "don't show up"
# until a logout. Finder/SystemUIServer auto-respawn via launchd.
/System/Library/CoreServices/pbs -flush 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true
echo "done"

_step "Writing config..."
if [[ ! -f "$CONFIG_FILE" ]]; then
    cp "$SCRIPT_DIR/pcpath_mappings.default" "$CONFIG_FILE"
    echo "done"
else
    echo "done (already existed, kept)"
fi

echo ""

# System Settings handoff (fallback — the steps above usually make the three
# actions appear on their own; this only matters if macOS left one disabled).
echo "If any action is missing, enable it under System Settings -> Finder:"
echo "  -> check \"Copy as PC Path\", \"Convert to Mac Path\", \"Copy Names\""
echo ""

_macos_major=$(sw_vers -productVersion | cut -d. -f1)
# macOS 15 (Sequoia) consolidated Extensions into General; macOS 26 (Tahoe)
# keeps it there. macOS 13 (Ventura) / 14 (Sonoma) still use Privacy & Security.
if [[ "$_macos_major" -ge 15 ]]; then
    echo "  macOS 15 (Sequoia) / 26 (Tahoe):"
    echo "  System Settings -> General -> Login Items & Extensions -> Finder (i)"
    open "x-apple.systempreferences:com.apple.LoginItems-Settings.extension" 2>/dev/null || \
        open "x-apple.systempreferences:" 2>/dev/null || true
else
    echo "  macOS 13 (Ventura) / 14 (Sonoma):"
    echo "  System Settings -> Privacy & Security -> Extensions -> Finder"
    open "x-apple.systempreferences:com.apple.ExtensionsPreferences" 2>/dev/null || \
        echo "  (Open System Settings manually -> search for \"Extensions\" -> select Finder)"
fi
echo ""

# Self-test
printf "Running self-test...\n"
source "$INSTALL_DIR/pcpath_common.sh"
pcpath_load_mappings
if [[ ${#vol_names[@]} -eq 0 ]]; then
    printf "  Warning: no mappings found in config -- skipping conversion test\n"
else
    _vol="${vol_names[0]}"
    _letter="${drive_letters[0]}"
    _input="/Volumes/${_vol}/Projects/test.mp4"
    _prefix="/Volumes/${_vol}/"
    _remainder="${_input:${#_prefix}}"
    _result="${_letter}:\\${_remainder}"
    _result="${_result//\//\\}"
    printf "  Input:   %s\n" "$_input"
    printf "  Output:  %s\n" "$_result"
    if [[ "$_result" == "${_letter}:\\Projects\\test.mp4" ]]; then
        echo "OK  Conversion working"
    else
        echo "FAIL  Conversion failed -- check $CONFIG_FILE"
        exit 1
    fi
fi

# Record install (after self-test passes)
echo "$(date -u +"%Y-%m-%dT%H:%M:%S") PCPath installed via manual installer" >> "$LOG_FILE"

echo ""
echo "OK  PCPath installed successfully"
echo ""
echo "Context menu actions:"
echo "  Copy as PC Path      Right-click a file or folder in Finder -> Quick Actions"
echo "  Convert to Mac Path  Right-click a file or folder in Finder -> Quick Actions"
echo "  Copy Names           Right-click selected file(s) in Finder -> Quick Actions"
echo ""
echo "Drive mappings: $CONFIG_FILE"
echo "Edit that file to add or change volume-to-drive-letter mappings."
