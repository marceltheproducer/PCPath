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
        # Not a drive-letter path, just normalize slashes
        mac_path="$pc_path"
    fi

    printf '%s' "$mac_path"
}

# Read input from arguments, stdin, or clipboard
if [[ $# -gt 0 ]]; then
    input="$(printf '%s\n' "$@")"
elif [[ ! -t 0 ]]; then
    input=$(cat)
else
    input=$(pbpaste)
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
    printf '%s' "$output" | pbcopy
    printf '%s' "$output"
fi
