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

    local source="$PCPATH_DEFAULTS"
    [[ -f "$PCPATH_CONFIG" ]] && source=$(cat "$PCPATH_CONFIG")

    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        # Split on first =
        local vol="${line%%=*}"
        local letter="${line#*=}"
        # Trim whitespace
        vol="$(echo "$vol" | tr -d ' ')"
        letter="$(echo "$letter" | tr -d ' ')"
        [[ -z "$vol" || -z "$letter" ]] && continue
        vol_names+=("$vol")
        drive_letters+=("$letter")
    done <<< "$source"
}
