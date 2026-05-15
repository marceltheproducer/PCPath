#!/bin/bash
# PCPath for macOS - Copy Names
# Copies the basename of each selected file/folder to the clipboard,
# one per line (newline-joined). Matches the Windows "Copy Names" verb.
#
# Invoked by the "Copy Names" Finder Quick Action with each selected path
# as a separate argument.

set -e

if [[ $# -eq 0 ]]; then
    osascript -e 'display notification "No file received — try right-clicking a file or folder" with title "PCPath"' 2>/dev/null || true
    exit 0
fi

names=""
for f in "$@"; do
    n="$(basename "$f")"
    if [[ -n "$names" ]]; then
        names+=$'\n'"$n"
    else
        names="$n"
    fi
done

# Copy to clipboard with osascript fallback for Quick Action contexts where
# pbcopy can fail.
_copied=false
if printf '%s' "$names" | pbcopy 2>/dev/null; then
    _copied=true
else
    _tmpfile="$(mktemp)"
    printf '%s' "$names" > "$_tmpfile"
    if osascript -e "set the clipboard to (read POSIX file \"$_tmpfile\")" 2>/dev/null; then
        _copied=true
    fi
    rm -f "$_tmpfile"
fi

if [[ "$_copied" == true ]]; then
    osascript -e 'display notification "Names copied to clipboard" with title "PCPath"' 2>/dev/null || true
else
    echo "Warning: Failed to copy to clipboard." >&2
    exit 1
fi
