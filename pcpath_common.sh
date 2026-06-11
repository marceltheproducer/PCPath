#!/bin/bash
# PCPath shared functions
# Sourced by copy_pc_path.sh and paste_mac_path.sh

PCPATH_CONFIG="$HOME/.pcpath_mappings"

# Default mappings (used when no config file exists)
PCPATH_DEFAULTS="CONTENT=K
GFX=G
EDIT=E
THE_NETWORK=N"

# Config file format (~/.pcpath_mappings), one directive per line:
#   VOLUME=LETTER   e.g.  EDIT=E
#   STRIP=SUFFIX    e.g.  STRIP=_LA   (strips that suffix from folder names;
#                   any STRIP= line replaces the built-in _LA default)

# Loads volume-to-drive-letter mappings into vol_names[] and drive_letters[]
pcpath_load_mappings() {
    vol_names=()
    drive_letters=()
    strip_suffixes=()
    local _strip_configured=false

    local config_data="$PCPATH_DEFAULTS"
    if [[ -f "$PCPATH_CONFIG" ]]; then
        if [[ -r "$PCPATH_CONFIG" ]]; then
            config_data=$(cat "$PCPATH_CONFIG")
        else
            echo "Warning: Cannot read $PCPATH_CONFIG (permission denied). Using default mappings." >&2
        fi
    fi

    while IFS= read -r line; do
        # Strip carriage returns (Windows line endings)
        line="${line//$'\r'/}"
        # Skip comments and empty lines
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        # STRIP=<suffix> directive (case-insensitive key)
        if [[ "$line" =~ ^[[:space:]]*[Ss][Tt][Rr][Ii][Pp][[:space:]]*= ]]; then
            local suf="${line#*=}"
            suf="${suf#"${suf%%[![:space:]]*}"}"
            suf="${suf%"${suf##*[![:space:]]}"}"
            _strip_configured=true
            [[ -n "$suf" ]] && strip_suffixes+=("$suf")
            continue
        fi
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
        # Validate drive letter is a single A-Z character
        [[ ! "$letter" =~ ^[A-Z]$ ]] && continue
        vol_names+=("$vol")
        drive_letters+=("$letter")
    done <<< "$config_data"
    # Default suffix when none configured.
    if [[ "$_strip_configured" == false ]]; then
        strip_suffixes=("_LA")
    fi
}

# Remove one layer of matching wrapping quotes (" or ').
strip_wrapping_quotes() {
    local s="$1"
    if [[ ${#s} -ge 2 ]]; then
        local f="${s:0:1}" l="${s: -1}"
        if [[ ( "$f" == '"' && "$l" == '"' ) || ( "$f" == "'" && "$l" == "'" ) ]]; then
            s="${s:1:${#s}-2}"
        fi
    fi
    printf '%s' "$s"
}

# Strip configured suffixes from each '/'-separated segment (exact, case-sensitive,
# only when it leaves a non-empty name; first match wins per segment).
strip_segment_suffixes() {
    local path="$1"
    [[ ${#strip_suffixes[@]} -eq 0 ]] && { printf '%s' "$path"; return; }
    local out="" rest="$path" seg
    while [[ "$rest" == */* ]]; do
        seg="${rest%%/*}"
        rest="${rest#*/}"
        out+="$(_strip_one_segment "$seg")/"
    done
    out+="$(_strip_one_segment "$rest")"
    printf '%s' "$out"
}

_strip_one_segment() {
    local seg="$1" suf
    for suf in "${strip_suffixes[@]}"; do
        [[ -z "$suf" ]] && continue
        if [[ "$seg" == *"$suf" && ${#seg} -gt ${#suf} ]]; then
            printf '%s' "${seg%"$suf"}"
            return
        fi
    done
    printf '%s' "$seg"
}
