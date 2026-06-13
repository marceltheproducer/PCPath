#!/bin/bash
# build_app_pkg.sh — Package the notarized PCPath.app + Finder extension into a
# Kandji-deployable .pkg. Installs the app to /Applications and a LaunchAgent
# that enables the extension per-user at login.
#
# Run AFTER macapp/build.sh has produced macapp/dist/PCPath.app.
#
# Usage:
#   ./kandji/build_app_pkg.sh 1.0.0                 # unsigned (testing)
#   ./kandji/build_app_pkg.sh 1.0.0 --sign          # signed + notarized pkg
#
# Env when signing:
#   DEVELOPER_ID_INSTALLER  "Developer ID Installer: Your Co (TEAMID)"
#   NOTARY_PROFILE          notarytool keychain profile

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

VERSION="${1:-1.0.0}"
SIGN=false
[[ "${2:-}" == "--sign" ]] && SIGN=true
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "ERROR: semver version required" >&2; exit 1; }

APP="$ROOT/macapp/dist/PCPath.app"
[[ -d "$APP" ]] || { echo "ERROR: $APP not found — run macapp/build.sh first" >&2; exit 1; }

BUILD="$(mktemp -d)"
PAYLOAD="$BUILD/payload"
SCRIPTS="$BUILD/scripts"
trap 'rm -rf "$BUILD"' EXIT

# --- assemble payload ---
mkdir -p "$PAYLOAD/Applications"
mkdir -p "$PAYLOAD/usr/local/pcpath"
mkdir -p "$PAYLOAD/Library/LaunchAgents"

cp -R "$APP" "$PAYLOAD/Applications/"
cp "$HERE/enable_extension.sh"                  "$PAYLOAD/usr/local/pcpath/"
cp "$ROOT/pcpath_mappings.default"              "$PAYLOAD/usr/local/pcpath/"
cp "$HERE/com.pcpath.finder-extension.plist"    "$PAYLOAD/Library/LaunchAgents/"

# --- postinstall (runs as root) ---
mkdir -p "$SCRIPTS"
cat > "$SCRIPTS/postinstall" <<'POST'
#!/bin/bash
set -e
SYS="/usr/local/pcpath"
chown -R root:wheel "$SYS"; chmod -R 755 "$SYS"
chmod 644 "$SYS/pcpath_mappings.default"
AGENT="/Library/LaunchAgents/com.pcpath.finder-extension.plist"
chown root:wheel "$AGENT"; chmod 644 "$AGENT"
# Enable for the user logged in right now (others get it at next login).
USER=$(stat -f "%Su" /dev/console 2>/dev/null)
if [[ -n "$USER" && "$USER" != "root" ]]; then
    UID_=$(id -u "$USER")
    launchctl asuser "$UID_" sudo -u "$USER" /bin/bash "$SYS/enable_extension.sh" || true
fi
exit 0
POST
chmod +x "$SCRIPTS/postinstall"

# --- build component pkg ---
COMPONENT="$BUILD/PCPath-component.pkg"
pkgbuild \
    --root "$PAYLOAD" \
    --scripts "$SCRIPTS" \
    --identifier "com.pcpath.app.pkg" \
    --version "$VERSION" \
    --install-location "/" \
    "$COMPONENT"

OUT="$ROOT/PCPath-app-$VERSION.pkg"
DISTRIBUTION="$BUILD/distribution.xml"
cat > "$DISTRIBUTION" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>PCPath</title>
    <options customize="never" require-scripts="false" hostArchitectures="arm64,x86_64"/>
    <volume-check><allowed-os-versions><os-version min="13.0"/></allowed-os-versions></volume-check>
    <pkg-ref id="com.pcpath.app.pkg" version="$VERSION">PCPath-component.pkg</pkg-ref>
    <choices-outline><line choice="default"/></choices-outline>
    <choice id="default"><pkg-ref id="com.pcpath.app.pkg"/></choice>
</installer-gui-script>
XML

if $SIGN; then
    : "${DEVELOPER_ID_INSTALLER:?Set DEVELOPER_ID_INSTALLER to sign}"
    productbuild --distribution "$DISTRIBUTION" --package-path "$BUILD" \
        --sign "$DEVELOPER_ID_INSTALLER" "$OUT"
    if [[ -n "${NOTARY_PROFILE:-}" ]]; then
        echo "==> Notarizing pkg"
        xcrun notarytool submit "$OUT" --keychain-profile "$NOTARY_PROFILE" --wait
        xcrun stapler staple "$OUT"
    fi
else
    productbuild --distribution "$DISTRIBUTION" --package-path "$BUILD" "$OUT"
fi

echo ""
echo "OK  Built $OUT"
echo "Upload to Kandji as a Custom App (Audit & Enforce or Install Once)."
