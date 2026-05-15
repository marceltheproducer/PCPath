#!/bin/bash
# PCPath - Convert Windows/PC paths to Mac file paths
# Reads PC path(s) from arguments, stdin, or clipboard.
# Copies the converted Mac path to clipboard and outputs it.
#
# Reads drive letter mappings from ~/.pcpath_mappings
# Falls back to built-in defaults if no config file exists.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/pcpath_common.sh" ]]; then
    source "$SCRIPT_DIR/pcpath_common.sh"
elif [[ -f "$HOME/.pcpath/pcpath_common.sh" ]]; then
    source "$HOME/.pcpath/pcpath_common.sh"
else
    echo "Error: pcpath_common.sh not found" >&2
    exit 1
fi

pcpath_load_mappings

convert_to_mac() {
    local pc_path="$1"
    local mac_path=""
    local matched=false

    # smb://server/share/rest  ->  /Volumes/share/rest
    # Hostname (bare or FQDN) is dropped; share is the volume name. URL-decoded
    # so %20 etc. round-trip cleanly.
    # Bash regex must be stored in a variable for backslash char classes to work.
    local re_smb='^[Ss][Mm][Bb]://[^/]+/(.*)$'
    if [[ "$pc_path" =~ $re_smb ]]; then
        local rest="${BASH_REMATCH[1]}"
        rest="${rest//+/ }"
        # URL-decode %HH using a self-contained loop so we don't depend on
        # python/perl and don't risk printf format-string interpretation.
        local decoded="" i=0 len=${#rest} c hex byte
        while (( i < len )); do
            c="${rest:i:1}"
            if [[ "$c" == "%" && $((i + 2)) -lt $len ]]; then
                hex="${rest:i+1:2}"
                if [[ "$hex" =~ ^[0-9A-Fa-f]{2}$ ]]; then
                    printf -v byte '\x'"$hex"
                    decoded+="$byte"
                    (( i += 3 ))
                    continue
                fi
            fi
            decoded+="$c"
            (( i++ ))
        done
        printf '%s' "/Volumes/$decoded"
        return
    fi

    # \Volumes\X\..., \\Volumes\X\..., /volumes/X/... (any case + slash mix)
    # -> canonical /Volumes/X/... — caught before the UNC reject below.
    local re_vol='^[\/\\]+[Vv]olumes[\/\\]'
    if [[ "$pc_path" =~ $re_vol ]]; then
        local norm="${pc_path//\\//}"
        norm="$(printf '%s' "$norm" | sed -E 's|^/+[Vv]olumes/|/Volumes/|')"
        printf '%s' "$norm"
        return
    fi

    # Reject UNC paths (\\server\share) — not supported
    if [[ "$pc_path" == \\\\* || "$pc_path" == //* ]]; then
        echo "Warning: UNC path not supported: $pc_path (use a mapped drive letter instead)" >&2
        printf '%s' "$pc_path"
        return
    fi

    # Normalize backslashes to forward slashes
    pc_path="${pc_path//\\//}"

    # Match drive letter pattern (e.g. K:/something or K:)
    if [[ "$pc_path" =~ ^([A-Za-z]): ]]; then
        local drive="${BASH_REMATCH[1]}"
        # Uppercase the drive letter for comparison
        drive="$(echo "$drive" | tr '[:lower:]' '[:upper:]')"
        local remainder="${pc_path:2}"  # everything after "K:"
        remainder="${remainder#/}"      # strip leading slash if present

        for i in "${!drive_letters[@]}"; do
            if [[ "${drive_letters[$i]}" == "$drive" ]]; then
                if [[ -n "$remainder" ]]; then
                    mac_path="/Volumes/${vol_names[$i]}/${remainder}"
                else
                    mac_path="/Volumes/${vol_names[$i]}"
                fi
                matched=true
                break
            fi
        done

        if [[ "$matched" == false ]]; then
            # Unknown drive letter — include letter so user knows which to map
            if [[ -n "$remainder" ]]; then
                mac_path="/Volumes/?(${drive})/${remainder}"
            else
                mac_path="/Volumes/?(${drive})"
            fi
        fi
    else
        # Not a drive-letter path, normalize slashes
        mac_path="$pc_path"
        # Handle paths missing /Volumes/ prefix (e.g. "EDIT/folder/..." → "/Volumes/EDIT/folder/...")
        if [[ ! "$mac_path" == /Volumes/* ]]; then
            local check_path="${mac_path#/}"
            shopt -s nocasematch
            for i in "${!vol_names[@]}"; do
                local vol="${vol_names[$i]}"
                if [[ "$check_path" == "$vol/"* || "$check_path" == "$vol" ]]; then
                    mac_path="/Volumes/$check_path"
                    break
                fi
            done
            shopt -u nocasematch
        fi
    fi

    printf '%s' "$mac_path"
}

# Read input from arguments, stdin, or clipboard
if [[ $# -gt 0 ]]; then
    input="$(printf '%s\n' "$@")"
elif [[ ! -t 0 ]]; then
    input=$(cat)
else
    if ! input=$(pbpaste 2>/dev/null) || [[ -z "$input" ]]; then
        # pbpaste can fail in Automator/Quick Action context — fall back to osascript
        input=$(osascript -e 'get the clipboard' 2>/dev/null) || true
    fi
    if [[ -z "$input" ]]; then
        echo "Error: Failed to read from clipboard." >&2
        exit 1
    fi
fi

# Convert each line
output=""
while IFS= read -r line; do
    # Trim leading/trailing whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    converted="$(convert_to_mac "$line")"
    if [[ -n "$output" ]]; then
        output="${output}"$'\n'"${converted}"
    else
        output="${converted}"
    fi
done <<< "$input"

if [[ -n "$output" ]]; then
    _copied=false
    if printf '%s' "$output" | pbcopy 2>/dev/null; then
        _copied=true
    else
        # pbcopy can fail in Automator/Quick Action context — fall back to osascript
        _tmpfile=$(mktemp)
        printf '%s' "$output" > "$_tmpfile"
        if osascript -e "set the clipboard to (read POSIX file \"$_tmpfile\")" 2>/dev/null; then
            _copied=true
        fi
        rm -f "$_tmpfile"
    fi
    if [[ "$_copied" == true ]]; then
        osascript -e 'display notification "Path copied to clipboard" with title "PCPath"' 2>/dev/null || true
    else
        echo "Warning: Failed to copy to clipboard." >&2
    fi
    printf '%s' "$output"
fi
