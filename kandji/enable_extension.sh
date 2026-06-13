#!/bin/bash
# enable_extension.sh — per-user setup for the PCPath Finder Sync extension.
# Runs at login via the com.pcpath.finder-extension LaunchAgent (user context).
#
# Idempotent: safe to run every login.

APP="/Applications/PCPath.app"
APPEX="$APP/Contents/PlugIns/PCPathFinderSync.appex"
EXT_ID="com.pcpath.PCPath.FinderSync"
CONFIG="$HOME/.pcpath_mappings"
DEFAULTS_SRC="/usr/local/pcpath/pcpath_mappings.default"

# 1. Seed the user's mappings file on first run (parity with the shell tool;
#    the extension reads ~/.pcpath_mappings, falling back to built-in defaults).
if [[ ! -f "$CONFIG" && -f "$DEFAULTS_SRC" ]]; then
    cp "$DEFAULTS_SRC" "$CONFIG" 2>/dev/null || true
fi

[[ -d "$APPEX" ]] || { echo "PCPath: extension not found at $APPEX" >&2; exit 0; }

# 2. Register the plug-in with PluginKit so Finder can see it, then enable it.
#    (-e use marks it enabled in the user's extension database.)
pluginkit -a "$APPEX" 2>/dev/null || true
pluginkit -e use -i "$EXT_ID" 2>/dev/null || true

# 3. Launch the container app once, headless, so Launch Services fully registers
#    the extension on a clean machine. (-g = don't bring to foreground.)
if ! pluginkit -m -i "$EXT_ID" 2>/dev/null | grep -q "$EXT_ID"; then
    open -g "$APP" 2>/dev/null || true
fi

exit 0
