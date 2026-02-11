#!/bin/bash
# PCPath - Convert Mac file paths to Windows/PC paths
# Used by the Automator Quick Action to copy a PC-compatible path to clipboard.
#
# Volume-to-drive-letter mappings:
#   /Volumes/CONTENT/     -> K:\
#   /Volumes/GFX/         -> G:\
#   /Volumes/EDIT/        -> E:\
#   /Volumes/THE_NETWORK/ -> N:\

convert_path() {
    local mac_path="$1"

    # Volume name -> drive letter mappings
    declare -a vol_names=("CONTENT" "GFX" "EDIT" "THE_NETWORK")
    declare -a drive_letters=("K" "G" "E" "N")

    local matched=false
    local pc_path=""

    for i in "${!vol_names[@]}"; do
        local vol="${vol_names[$i]}"
        local letter="${drive_letters[$i]}"
        local prefix="/Volumes/${vol}/"

        if [[ "$mac_path" == "$prefix"* ]]; then
            # Strip the /Volumes/<name>/ prefix and prepend the drive letter
            local remainder="${mac_path#$prefix}"
            pc_path="${letter}:\\${remainder}"
            matched=true
            break
        fi

        # Also handle the case where the path IS the volume root (no trailing content)
        if [[ "$mac_path" == "/Volumes/${vol}" ]]; then
            pc_path="${letter}:\\"
            matched=true
            break
        fi
    done

    if [[ "$matched" == false ]]; then
        # If no volume matched, still convert slashes but keep the path as-is
        pc_path="$mac_path"
    fi

    # Replace forward slashes with backslashes
    pc_path="${pc_path//\//\\}"

    printf '%s' "$pc_path"
}

# When called from Automator, file paths come in as arguments.
# Collect all converted paths (one per line) and copy them all to the clipboard.
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
