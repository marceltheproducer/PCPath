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

if [[ $# -eq 0 ]]; then
    osascript -e 'display notification "No file received — try right-clicking a file or folder" with title "PCPath"' 2>/dev/null || true
    exit 0
fi

convert_path() {
    local mac_path="$1"
    local pc_path=""
    local matched=false

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

    shopt -s nocasematch
    for i in "${!vol_names[@]}"; do
        local vol="${vol_names[$i]}"
        local letter="${drive_letters[$i]}"
        local prefix="/Volumes/${vol}/"

        if [[ "$mac_path" == "$prefix"* ]]; then
            # Use length-based slicing to preserve original case in remainder
            local remainder="${mac_path:${#prefix}}"
            pc_path="${letter}:/${remainder}"
            matched=true
            break
        fi

        if [[ "$mac_path" == "/Volumes/${vol}" ]]; then
            pc_path="${letter}:/"
            matched=true
            break
        fi
    done
    shopt -u nocasematch

    if [[ "$matched" == false ]]; then
        if [[ "$mac_path" == /Volumes/* ]]; then
            # Unmapped volume — use ?(VOL_NAME) as a placeholder drive letter
            local after_volumes="${mac_path#/Volumes/}"
            local vol_name="${after_volumes%%/*}"
            if [[ "$after_volumes" == */* ]]; then
                local remainder="${after_volumes#*/}"
                pc_path="?(${vol_name}):/${remainder}"
            else
                pc_path="?(${vol_name}):/"
            fi
        else
            # Non-volume path (e.g. /Users/..., /tmp/...) — cannot convert
            echo "Warning: Not a /Volumes/ path, cannot convert: $mac_path" >&2
            pc_path="$mac_path"
        fi
    fi

    # Strip suffixes while the path is still '/'-separated (drive letter is its
    # own segment), THEN convert to backslashes. Stripping before the conversion
    # is required: strip_segment_suffixes splits on '/', so a backslash-glued
    # "E:\seg" would be one segment and defeat the per-segment length guard.
    pc_path="$(strip_segment_suffixes "$pc_path")"
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
    # Shortcuts / stdout mode: print the result and let the caller (e.g. a
    # Shortcuts "Copy to Clipboard" action) own the clipboard. This avoids
    # pbcopy running inside a sandboxed Quick Action context.
    if [[ "$PCPATH_OUTPUT_MODE" == "print" ]]; then
        printf '%s' "$output"
        exit 0
    fi
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
fi
