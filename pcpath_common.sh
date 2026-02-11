#!/bin/bash
# PCPath shared functions
# Sourced by copy_pc_path.sh and paste_mac_path.sh

PCPATH_CONFIG="$HOME/.pcpath_mappings"

# Default mappings (used when no config file exists)
PCPATH_DEFAULTS="CONTENT=K
GFX=G
EDIT=E
THE_NETWORK=N"

# Loads volume-to-drive-letter mappings into vol_names[] and drive_letters[]
pcpath_load_mappings() {
    vol_names=()
    drive_letters=()

    local config_data="$PCPATH_DEFAULTS"
    [[ -f "$PCPATH_CONFIG" && -r "$PCPATH_CONFIG" ]] && config_data=$(cat "$PCPATH_CONFIG")

    while IFS= read -r line; do
        # Strip carriage returns (Windows line endings)
        line="${line//$'\r'/}"
        # Skip comments and empty lines
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        # Split on first =
        local vol="${line%%=*}"
        local letter="${line#*=}"
        # Trim leading/trailing whitespace (preserves internal spaces in volume names)
        vol="${vol#"${vol%%[![:space:]]*}"}"
        vol="${vol%"${vol##*[![:space:]]}"}"
        letter="${letter#"${letter%%[![:space:]]*}"}"
        letter="${letter%"${letter##*[![:space:]]}"}"
        letter="$(echo "$letter" | tr '[:lower:]' '[:upper:]')"
        [[ -z "$vol" || -z "$letter" ]] && continue
        vol_names+=("$vol")
        drive_letters+=("$letter")
    done <<< "$config_data"
}
