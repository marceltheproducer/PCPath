#!/bin/bash
# test_local.sh — Register, enable, and load the locally-built PCPath.app so you
# can test the Finder extension on this Mac. Pairs with build_local_clt.sh.

set -uo pipefail
APP="$HOME/PCPathLocalTest/PCPath.app"
APPEX="$APP/Contents/PlugIns/PCPathFinderSync.appex"
EXT_ID="com.pcpath.PCPath.FinderSync"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

[[ -d "$APP" ]] || { echo "Build it first: ./build_local_clt.sh" >&2; exit 1; }

echo "==> Registering app with Launch Services"
"$LSREGISTER" -f "$APP"

echo "==> Registering + enabling the extension (pluginkit)"
pluginkit -a "$APPEX"
pluginkit -e use -i "$EXT_ID"

echo "==> Launching the app once (registers the extension), then relaunching Finder"
open "$APP"
sleep 1
killall Finder 2>/dev/null || true

echo ""
echo "==> Extension status:"
pluginkit -m -v -i "$EXT_ID" || echo "  (not listed yet — give it a few seconds and re-run)"

echo ""
echo "Now: right-click a file under /Volumes/EDIT (or /Volumes/DEV) →"
echo "     Quick Actions → Copy as PC Path → paste. Expect E:\\… or V:\\…"
