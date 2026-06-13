#!/bin/bash
# build_local_clt.sh — Build a TESTABLE, ad-hoc-signed PCPath.app using only the
# Command Line Tools (no Xcode, no Developer ID). Runs ONLY on the Mac that built
# it — for validating the Finder extension on Tahoe before investing in signing.
#
# The real distributable build is build.sh (needs Xcode + Developer ID).

set -euo pipefail
cd "$(dirname "$0")"

SDK=$(xcrun --show-sdk-path)
TARGET="arm64-apple-macos13.0"
VER="1.0.0"
# Build on local APFS, NOT the SMB share — codesign rejects SMB's xattr detritus.
BUILDROOT="$HOME/PCPathLocalTest"
OUT="$BUILDROOT/PCPath.app"
EXT="$OUT/Contents/PlugIns/PCPathFinderSync.appex"

rm -rf "$BUILDROOT"
mkdir -p "$OUT/Contents/MacOS" "$EXT/Contents/MacOS"

echo "==> Compiling extension (module PCPathFinderSync, entry NSExtensionMain)"
swiftc -sdk "$SDK" -target "$TARGET" -module-name PCPathFinderSync \
    Sources/PCPathKit/PathConverter.swift Sources/FinderSync/FinderSync.swift \
    -framework FinderSync -framework Cocoa \
    -Xlinker -e -Xlinker _NSExtensionMain \
    -o "$EXT/Contents/MacOS/PCPathFinderSync"

echo "==> Compiling app (module PCPath)"
swiftc -sdk "$SDK" -target "$TARGET" -module-name PCPath \
    Sources/PCPathKit/PathConverter.swift Sources/PCPathApp/PCPathApp.swift \
    -framework SwiftUI -framework AppKit \
    -o "$OUT/Contents/MacOS/PCPath"

echo "==> Writing Info.plists"
cat > "$OUT/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>PCPath</string>
  <key>CFBundleIdentifier</key><string>com.pcpath.PCPath</string>
  <key>CFBundleName</key><string>PCPath</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VER</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST

cat > "$EXT/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>PCPathFinderSync</string>
  <key>CFBundleIdentifier</key><string>com.pcpath.PCPath.FinderSync</string>
  <key>CFBundleName</key><string>PCPathFinderSync</string>
  <key>CFBundlePackageType</key><string>XPC!</string>
  <key>CFBundleShortVersionString</key><string>$VER</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>NSExtension</key><dict>
    <key>NSExtensionPointIdentifier</key><string>com.apple.FinderSync</string>
    <key>NSExtensionPrincipalClass</key><string>PCPathFinderSync.FinderSync</string>
  </dict>
</dict></plist>
PLIST

echo "==> Stripping xattrs (repo is on an SMB share; codesign rejects detritus)"
xattr -cr "$OUT"

echo "==> Ad-hoc signing (extension first, then app)"
codesign --force --sign - --entitlements Sources/FinderSync/FinderSync.entitlements "$EXT"
codesign --force --sign - --entitlements Sources/PCPathApp/PCPathApp.entitlements "$OUT"
codesign --verify --verbose=1 "$OUT" && echo "signature OK"

echo ""
echo "OK  Built $OUT  (ad-hoc, this Mac only)"
echo "Test it with:  ./test_local.sh"
echo "$OUT" > "$BUILDROOT/.app_path"
