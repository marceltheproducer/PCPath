#!/bin/bash
# PCPath - Convert Mac file paths to Windows/PC paths
# Copies the converted path(s) to the clipboard.
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

convert_path() {
    local mac_path="$1"
    local pc_path=""
    local matched=false

    for i in "${!vol_names[@]}"; do
        local vol="${vol_names[$i]}"
        local letter="${drive_letters[$i]}"
        local prefix="/Volumes/${vol}/"

        if [[ "$mac_path" == "$prefix"* ]]; then
            local remainder="${mac_path#$prefix}"
            pc_path="${letter}:\\${remainder}"
            matched=true
            break
        fi

        if [[ "$mac_path" == "/Volumes/${vol}" ]]; then
            pc_path="${letter}:\\"
            matched=true
            break
        fi
    done

    if [[ "$matched" == false ]]; then
        if [[ "$mac_path" == /Volumes/* ]]; then
            # Unmapped volume — use ?(VOL_NAME) as a placeholder drive letter
            local after_volumes="${mac_path#/Volumes/}"
            local vol_name="${after_volumes%%/*}"
            if [[ "$after_volumes" == */* ]]; then
                local remainder="${after_volumes#*/}"
                pc_path="?(${vol_name}):\\${remainder}"
            else
                pc_path="?(${vol_name}):\\"
            fi
        else
            pc_path="$mac_path"
        fi
    fi

    # Replace forward slashes with backslashes
    pc_path="${pc_path//\//\\}"

    printf '%s' "$pc_path"
}

# Collect all converted paths and copy to clipboard
output=""
for f in "$@"; do
    converted="$(convert_path "$f")"
    if [[ -n "$output" ]]; then
        output="${output}"$'\n'"${converted}"
    else
        output="${converted}"
    fi
done

if [[ -n "$output" ]]; then
    printf '%s' "$output" | pbcopy
fi
