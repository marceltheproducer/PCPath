# PCPath — macOS app + Finder Sync extension

The company-deployable replacement for the legacy Automator Quick Actions, which
register but **do not execute** on macOS 26 (Tahoe). A Finder Sync extension is
the supported, MDM-pushable way to add right-click menu items on modern macOS
(the same mechanism Dropbox et al. use), and it actually runs on Tahoe.

## What it adds

Right-click a file/folder on a network volume → **Quick Actions**:

| Item | Action |
|------|--------|
| Copy as PC Path | Selected Mac paths → `V:\…`, `E:\…` on the clipboard |
| Copy Names | Selected item names, one per line |
| Convert to Mac Path (from clipboard) | Reads a `V:\…` path from the clipboard → `/Volumes/…` |

The menu appears for items under **`/Volumes`** (every mapped share). Conversion
logic is shared, unit-tested Swift — identical rules to the Windows `.ps1` and
web tool.

## Layout

```
macapp/
├── project.yml                       # XcodeGen spec → PCPath.xcodeproj
├── build.sh                          # build + sign + notarize + staple
├── Sources/
│   ├── PCPathKit/PathConverter.swift # conversion core (single source of truth)
│   ├── FinderSync/                   # the extension (FIFinderSync subclass)
│   │   ├── FinderSync.swift
│   │   └── FinderSync.entitlements
│   └── PCPathApp/                    # container app (enable + edit mappings)
│       ├── PCPathApp.swift
│       └── PCPathApp.entitlements
└── Tests/PathConverterTests.swift    # swiftc-runnable; no Xcode needed
```

`PathConverter.swift` is compiled into **both** the app and the extension.

## Build prerequisites (build Mac only — not every user's machine)

- **Full Xcode** (not just Command Line Tools): `xcode-select -s /Applications/Xcode.app`
- **XcodeGen**: `brew install xcodegen`
- **Developer ID Application** + **Developer ID Installer** certs in the keychain
- A **notarytool** keychain profile (one-time):
  ```
  xcrun notarytool store-credentials "PCPath" \
    --apple-id you@company.com --team-id ABCDE12345 \
    --password <app-specific-password>
  ```

## Build & package

```bash
# 1. Build, sign, notarize, staple the app
cd macapp
export DEVELOPER_ID_APP="Developer ID Application: Your Co (ABCDE12345)"
export TEAM_ID="ABCDE12345"
export NOTARY_PROFILE="PCPath"
./build.sh 1.0.0 --notarize          # → macapp/dist/PCPath.app

# 2. Wrap into a Kandji-deployable pkg
cd ..
export DEVELOPER_ID_INSTALLER="Developer ID Installer: Your Co (ABCDE12345)"
./kandji/build_app_pkg.sh 1.0.0 --sign   # → PCPath-app-1.0.0.pkg
```

Run the conversion tests anytime (no Xcode needed):
```bash
swiftc Sources/PCPathKit/PathConverter.swift Tests/PathConverterTests.swift Tests/main.swift -o /tmp/t && /tmp/t
```

## Deployment (Kandji / any MDM)

The pkg installs:
- `/Applications/PCPath.app` (contains the extension in `Contents/PlugIns/`)
- `/Library/LaunchAgents/com.pcpath.finder-extension.plist` → runs
  `enable_extension.sh` per-user at login, which registers + enables the
  extension (`pluginkit`) and seeds `~/.pcpath_mappings`.

Upload `PCPath-app-<version>.pkg` to Kandji as a **Custom App**. Build once,
push to everyone — no per-machine manual project setup.

### Enablement caveat (read this)

`pluginkit -e use` enables the extension programmatically and has worked across
macOS releases. **If a given macOS build still requires a user to flip the
toggle** (System Settings → General → Login Items & Extensions → Finder), that
is a single switch — and unlike the old Automator actions, once on it *actually
runs*. To make even that switch unnecessary, push an MDM profile that
pre-approves the extension; verify on a pilot machine before the full rollout.

## Config

The extension reads **`~/.pcpath_mappings`** (same file as the shell tool),
falling back to built-in defaults (`CONTENT=K, GFX=G, EDIT=E, THE_NETWORK=N,
DEV=V`, strip `_LA`) if it's missing — so the menu still works before the file
is seeded. Sandbox access to that file is granted by a notarizable
`temporary-exception.files.home-relative-path` entitlement.

> If mappings ever silently fall back to defaults on a built/signed copy, verify
> the entitlement path format (`/.pcpath_mappings`) on the build Mac — the
> fallback is intentional so a path mismatch degrades gracefully instead of
> breaking the menu.

## Why this replaces the Automator workflows

The `.workflow` bundles + `install.sh` Quick Actions are kept for older macOS,
but on Tahoe they appear under the Services submenu and silently no-op when
clicked (no runner launches). This extension is the forward path.
