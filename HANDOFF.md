# PCPath — Handoff / Context

Last touched: 2026-07-23. Owner: Marcel Perez.

PCPath converts file paths between Mac (`/Volumes/...`) and Windows (`K:\...`)
formats via right-click context menu actions on both OSes, plus a no-install
web converter for everything else.

> **Mac Finder Sync extension is BUILT and SHIPPED (2026-06-27).** The signed
> (Developer ID, Team `6M993C5R86`), notarized + stapled **`PCPath-app-1.0.1.pkg`**
> is in the IT distribution folders, ready for Kandji. The extension is sandboxed
> and shares a **App Group container** (`6M993C5R86.com.pcpath.shared`) with the
> container app for the drive-mappings file — the temporary-exception home-path
> approach was abandoned because a sandboxed extension genuinely can't read
> `~/.pcpath_mappings`. Kandji rollout steps: `_Out/PCPath/IRU-DEPLOY.md`.
> Windows installer is now at **2.4** (shipped 2026-07-15 with UNC input
> support). See "Mac right-click — two mechanisms" and "Open items" below.

---

## Current versions

| Surface  | Version | Notes |
|----------|---------|-------|
| Windows installer | **2.4** (build stamp `YYYY.MM.DD.HHMM`) | NSIS exe, auto-updates, no PowerShell required |
| Web converter     | **v1.5.0** (`PCPath_v1.5.0.html`) | Self-contained, dark mode, inline-SVG favicon |
| Mac install (legacy) | No version stamp (manual `install.sh` / curl one-liner) | Automator Quick Actions — **broken on Tahoe** |
| Mac app + extension   | **1.0.1** shipped; **1.0.2 pending** (UNC support in source, needs build Mac) | Finder Sync extension; signed (Team `6M993C5R86`), notarized + stapled; `PCPath-app-1.0.1.pkg` in distribution; App Group container |

Bump Windows by editing `!define PCPATH_VERSION "2.4"` in `windows/PCPathInstall.nsi`
(or just run `sync.ps1` — it auto-bumps the minor).

---

## Right-click verbs (feature parity)

| Windows verb | Mac equivalent | Notes |
|---|---|---|
| Copy as Mac Path | Copy as PC Path (reverse direction) | Multi-select → CRLF-joined |
| Copy as Path     | Built into Finder (Option+right-click → "Copy as Pathname") | Windows path format |
| Copy Names       | Copy Names | Filenames only, one per line |
| Convert to PC Path (background / desktop) | Convert to Mac Path | Reads clipboard |

Path-shape coverage (all four implementations match — Windows ps1, Mac sh, Mac
Swift, web JS):
- `/Volumes/<vol>/...` (canonical)
- `smb://server/share/...` (bare hostname OR FQDN, URL-decoded)
- `\Volumes\X\...`, `\\Volumes\X\...`, `/volumes/X/...` (case + slash variants)
- `\\server\share\...` (UNC — host dropped, share == volume name; `\\?\` and `\\.\` device paths and `//host/share` pass through)

---

## Mac right-click — two mechanisms

| Mechanism | macOS | Status |
|---|---|---|
| **Automator Quick Actions** (`*.workflow/` + `install.sh`) | ≤ 15 (Sequoia) | Works, but **silently no-ops on macOS 26 Tahoe** — registers under Services and never runs |
| **Finder Sync extension** (`macapp/`) | modern, incl. Tahoe | **Forward path. BUILT + SHIPPED at 1.0.1.** Signed/notarized `.pkg` in distribution, MDM-pushable via Kandji |

The Finder Sync extension uses `macapp/Sources/PCPathKit/PathConverter.swift` —
a Foundation-only, unit-tested **single source of truth** for conversion. It
also fixes a latent `_LA` suffix-strip bug still present in the shell version
(`copy_pc_path.sh` strips on a backslash-glued string; see Open items). Both the
app and the extension compile the same `PathConverter.swift`.

**Mappings storage — App Group, not `~/.pcpath_mappings`.** Both the app and the
extension are sandboxed (mandatory: Finder won't load an unsandboxed Sync
extension on Tahoe), and a sandboxed process cannot read `~/.pcpath_mappings`.
So the file lives in the shared App Group container
`6M993C5R86.com.pcpath.shared` (`PCPathConfig.mappingsURL`), written by the app
and read by both. `PCPathConfig.mappingsURL` falls back to `~/.pcpath_mappings`
when the container is nil (shell tools + unsandboxed dev builds), preserving the
cross-tool convention. The App Group + sandbox entitlements are declared in
`macapp/project.yml` under each target's `entitlements.properties` — **hand-edits
to the `.entitlements` files don't survive `xcodegen generate`.** The pkg is
non-relocatable (`BundleIsRelocatable false` in `kandji/build_app_pkg.sh`) so it
always installs to `/Applications`, never "updates in place" a stray dev build.

Build/rollout docs: `macapp/README.md`. Requires a build Mac with **full Xcode**,
XcodeGen, Developer ID certs, and a notarytool profile.

---

## File sync locations (4)

Per project memory — **every change to a shared file must propagate to all 4:**

| # | Path | Role |
|---|------|------|
| 1 | `v:\General Dev\Design\PCPath\` | **Source of truth** (git, source repo) |
| 2 | `V:\General Dev\Design\_Out\PCPath\` | IT distribution folder (split into `mac/`, `windows/`) |
| 3 | `c:\Users\marcel.perez\work\PCPath\PCPath\` | GitHub clone (`github.com/marceltheproducer/PCPath`) — push from here |
| 4 | `G:\_library\Tech\DevOps\PCPath\` | GFX server flat folder where IT actually installs from |

`sync.ps1` automates 1→{2,3,4}, commits 1 and 3, pushes 3 to GitHub. **Dev tooling**
(`sync.ps1`, `sync.cmd`, `build_installer.ps1`) is *excluded* from 2 and 4 — they
stay in the source repos only.

---

## Release pipeline

From inside `windows\`:

```powershell
.\sync.cmd                   # default: bump minor, build, sync, commit, push, launch installer
.\sync.ps1                   # same but no installer launch
.\sync.ps1 -NoBump           # ship current version (retry / republish)
.\sync.ps1 -BumpMajor        # 2.x -> 3.0
.\sync.ps1 -CommitMessage "..."
```

Pipeline order:
1. Read/bump `PCPATH_VERSION` in `PCPathInstall.nsi` (UTF-8-safe read so em-dashes survive)
2. Run `makensis` to rebuild `PCPathInstall.exe` (build timestamp auto-stamped)
3. Copy `windows\*` to `_Out\windows`, GitHub clone, and `G:\` — resilient to locked files (warns, continues)
4. `git add` + commit in main repo and GitHub clone
5. `git push origin main` from GitHub clone

Critical gotchas (already handled, don't re-introduce):
- **Get-Content UTF-8 flag.** Without `-Encoding UTF8`, PS 5.1 reads with system codepage and corrupts non-ASCII chars (`—` → `â€"`) on save.
- **Native git stderr redirection.** Do *not* use `2>&1` on `git` in PS 5.1 — `$ErrorActionPreference = "Stop"` turns CRLF warnings into terminating errors.
- **MultiSelectModel = Player.** Without it, Windows fires the shell verb once per file → N PowerShell processes racing the clipboard. Don't remove from any of the 4 multi-select verbs.
- **VBScript launcher (`pcpath_launch.vbs`).** Hides the PowerShell console (no flash) by running `WScript.Shell.Run` with style 0. All 9 verbs route through it.

---

## Installation paths

### Windows (recommended)
`G:\_library\Tech\DevOps\PCPath\PCPathInstall.exe` — double-click. Detects existing installs and shows "Updating: <old> → 2.4".

### Mac (recommended)
From a mounted SMB share or local copy of the PCPath folder:
```bash
bash install.sh
```
Then enable three Quick Actions in System Settings → ... → Finder.

### Mac (one-liner with internet)
```bash
curl -fsSL https://raw.githubusercontent.com/marceltheproducer/PCPath/main/remote_install.sh | bash
```

### MDM-pushed (Kandji)
`kandji/build_pkg.sh` on a Mac with Xcode CLI tools → signed .pkg → upload as Custom App.

### Web
`PCPath_v1.5.0.html` — open in any browser. No install. localStorage-backed mappings.

---

## File inventory (what's in the source repo)

```
PCPath/
├── windows/
│   ├── PCPathInstall.exe / .nsi                 # NSIS installer (versioned)
│   ├── build_installer.ps1                      # legacy single-build script
│   ├── sync.ps1 / sync.cmd                      # release pipeline (dev-only, not shipped to IT)
│   ├── install.ps1 / uninstall.ps1              # manual PS install path
│   ├── remote_install.ps1                       # one-liner installer
│   ├── verify.ps1                               # checks registry, scripts, mappings
│   ├── pcpath_common.ps1                        # shared mapping loader
│   ├── pcpath_launch.vbs                        # silent PS launcher (hides console)
│   ├── copy_mac_path.ps1                        # right-click verb: -> /Volumes/...
│   ├── copy_path.ps1                            # right-click verb: Windows paths, CRLF
│   ├── copy_names.ps1                           # right-click verb: names, CRLF
│   └── convert_to_pc_path.ps1                   # background verb: clipboard -> drive path
├── (mac scripts at repo root)
│   ├── install.sh / uninstall.sh / verify.sh
│   ├── remote_install.sh
│   ├── pcpath_common.sh
│   ├── copy_pc_path.sh                          # Quick Action: -> K:\...
│   ├── paste_mac_path.sh                        # Quick Action: clipboard -> /Volumes/
│   └── copy_names.sh                            # Quick Action: names CRLF
├── Copy as PC Path.workflow/                    # Automator Quick Action bundles (legacy, ≤ macOS 15)
├── Convert to Mac Path.workflow/
├── Copy Names.workflow/
├── macapp/                                       # NEW: Finder Sync extension (Tahoe-safe, branch only)
│   ├── Sources/PCPathKit/PathConverter.swift    #   conversion core — single source of truth
│   ├── Sources/FinderSync/                       #   FIFinderSync extension (4 verbs)
│   ├── Sources/PCPathApp/                        #   container app (enable + edit mappings)
│   ├── Tests/PathConverterTests.swift            #   swiftc-runnable, no Xcode
│   ├── project.yml / build.sh                    #   XcodeGen spec + sign/notarize
│   └── README.md                                 #   build + rollout docs
├── kandji/                                      # MDM build + per-user setup (incl. build_app_pkg.sh, enable_extension.sh)
├── web/PCPath_v1.5.0.html                       # standalone web converter
├── pcpath_mappings.default                      # ships as ~/.pcpath_mappings on first install
└── HANDOFF.md                                   # this file
```

---

## Drive mappings (default)

```
CONTENT=K
GFX=G
EDIT=E
THE_NETWORK=N
DEV=V
```

Lives at `~/.pcpath_mappings` (Mac) / `%USERPROFILE%\.pcpath_mappings` (Windows).
Edit per machine; case-insensitive lookup so `Edit` finds `EDIT`.

---

## Recent work

### Release close-out + portal hygiene (2026-07-23)
- **Portal publish for 2.4 completed** — the 2026-07-15 session uploaded the 2.4
  build to the portal but never flipped it live (state was "ahead", live 2.3).
  Re-ran `publish_version` + upload curl; portal now **in-sync, live 2.4**.
  `.portal-release.yaml` bump committed (`4cf865b`).
- **Notion row refreshed** — Recent Changes + Last Code Update now describe the
  2.4/v1.5.0 UNC release; **Mac Path field set** to
  `//calamedia/GFX/_library/Tech/DevOps/PCPath/PCPath-app-1.0.1.pkg`, so the
  portal card now offers the Mac installer (PeepIt convention). **Bump this
  field when 1.0.2 ships.**
- **Dev-tooling exclusion actually implemented** — `sync.ps1` had been copying
  `sync.ps1`/`sync.cmd`/`build_installer.ps1` to `_Out\windows` and `G:\`
  despite this doc claiming they were excluded. Script now filters IT-facing
  destinations (GitHub clone still gets everything); stray copies deleted from
  both locations (`116e122`).
- Legacy `.workflow` folders left on `G:\` on purpose — still the install path
  for ≤ macOS 15 until the Kandji rollout replaces them.

### UNC input support + 2.4 release (2026-07-15)
- All five conversion surfaces (Windows PS scripts, Mac `paste_mac_path.sh`, Mac
  `PathConverter.swift`, web) now accept `\\server\share\...` UNC input, mirroring
  the existing `smb://` handling: host is dropped, share becomes the volume name;
  `\\?\` and `\\.\` device-path prefixes and `//host/share` forms pass through
  unmangled. Design spec at
  `docs/superpowers/specs/2026-07-15-unc-input-design.md`.
- Web converter renamed/bumped to **v1.5.0** (`PCPath_v1.5.0.html`).
- Windows installer bumped **2.3 → 2.4** via `sync.ps1`.
- Swift `PathConverter.swift` + `Tests/PathConverterTests.swift` updated with UNC
  coverage; **Mac app rebuild deferred to 1.0.2** — ships at the next build-Mac
  session (needs Xcode/notarytool), source is committed now.

### Mac extension build + ship (2026-06-27)
- Built, signed (Developer ID, Team `6M993C5R86`), notarized + stapled
  **`PCPath-app-1.0.1.pkg`**; placed in `_Out/PCPath/mac/` and `G:\…\PCPath\`.
- **App Group migration:** mappings file moved from `~/.pcpath_mappings`
  (unreachable from a sandboxed extension) to the shared App Group container
  `6M993C5R86.com.pcpath.shared`. Entitlements now declared in `project.yml`
  `entitlements.properties` so `xcodegen generate` writes them; both targets
  sandboxed + share the group. `PathConverter.swift` gains `appGroupID` /
  `mappingsURL` with `~/.pcpath_mappings` fallback.
- **Notarization fix:** `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` to strip
  `get-task-allow` (commit `1334863`).
- **Installer fix:** non-relocatable pkg (`BundleIsRelocatable false`) so it
  always lands in `/Applications`.
- New `_Out/PCPath/IRU-DEPLOY.md` — Kandji upload + auto-enable profile steps.

### Mac Finder Sync extension (branch `mac-finder-extension`, commit `1d886ab`, Jun 2026)
- New `macapp/` — signed/notarized app + `FIFinderSync` extension replacing the
  Tahoe-broken Automator actions; 4 verbs, monitors `/` + all `/Volumes` mounts.
- `PathConverter.swift` — Foundation-only conversion core, now the single source
  of truth, unit-tested via `swiftc` (no Xcode). Fixes the `_LA` shell suffix bug.
- `kandji/build_app_pkg.sh` + `enable_extension.sh` + LaunchAgent for MDM rollout.
- `DEV=V` added to default mappings; `install.sh`/`verify.sh` hardening.
- **Not yet released** — lives on the branch; not merged to `main` or synced.

### Prior session
- Windows **Copy Names** verb + **Copy as Path** verb (multi-select via `MultiSelectModel=Player`, silent via VBS launcher, grouped via `Position=Top`)
- `convert_to_pc_path.ps1` now handles `smb://...` and `\Volumes\...`
- `paste_mac_path.sh` (Mac) handles the same — self-contained bash URL-decoder, no python/perl dep
- Web v1.2.0 → **v1.3.0** → **v1.4.0**: matching normalization + inline-SVG favicon; v1.4.0 adds Path Opener parity (wrapping-quote strip + configurable `STRIP=` suffix UI, default `_LA`)
- Mac **Copy Names** Quick Action + script (`copy_names.sh`, `Copy Names.workflow/`)
- Mac install fixes shipped: `pbs -flush`, idempotent re-install, version-aware Settings deep-link, `pbcopy` → `osascript` fallback
- Windows installer **2.0** → **2.1** → **2.2** → **2.3** with auto-update detection, build-stamped, listed in Add/Remove Programs; 2.3 ships Path Opener parity (quote-strip, `STRIP=` suffix stripping, drive-label auto-discovery fallback)
- New release pipeline: `windows/sync.ps1` + `sync.cmd` double-click shim
- IT setup doc rewritten for current state (in `_Out/` and `G:\`)

---

## Open items / known limitations

- **Mac app 1.0.2 rebuild pending** — UNC support committed in
  `PathConverter.swift` + tests; build/sign/notarize per `macapp/README.md` at
  the next build-Mac session, then update the Kandji pkg, the pkg in
  `_Out/PCPath/mac/` + `G:\`, and the Notion row's **Mac Path** field
  (currently points at the 1.0.1 pkg).
- **Mac Finder extension: BUILT + SHIPPED (2026-06-27).** Signed, notarized +
  stapled `PCPath-app-1.0.1.pkg` is in `_Out/PCPath/mac/` and `G:\…\PCPath\`,
  ready to upload to Kandji per `_Out/PCPath/IRU-DEPLOY.md`. The `.pkg` is
  **gitignored** (`kandji/*.pkg`) — it lives in the distribution folders only,
  never in the repo. Source (App Group migration + non-relocatable pkg fix) is
  committed + pushed. *Next:* pilot on one clean Mac; if the right-click menu
  appears without a System Settings toggle, ship org-wide, else add the managed
  Login Items & Extensions profile for Team `6M993C5R86` (see IRU-DEPLOY.md).
- **`_LA` suffix-strip bug in the shell tool — FIXED on this branch.**
  `copy_pc_path.sh` now builds the PC path with `/` (drive letter as its own
  segment), strips, then converts to `\` — matching Swift + web. This corrects a
  folder named exactly `_LA` being wrongly dropped and keeps the per-segment
  length guard intact. Covered by `tests/run_shell.sh` ("never empties segment").
  Ships with the next Mac sync. (Was: built `E:\seg` glued, defeating the guard.)
- **macOS enable step** — Apple requires the user to check Quick Actions in System Settings. No automation possible (Privacy & Security model).
- **Mac install has no version stamp** — `install.log` exists but no `version.txt` equivalent. Low priority; pkg path (Kandji) has version metadata.
- ~~Pre-existing dirty files in git~~ — **resolved**: committed during the 2.4 release session; working tree clean as of 2026-07-23.
- **The G:\ install location** — sometimes `PCPathInstall.exe` is locked there during a re-sync if a previous installer window is still open. `sync.ps1` warns and continues; user just closes the dialog and re-runs.

---

## Where to look first

| Question | File |
|---|---|
| How does conversion logic work? (Windows) | `windows/convert_to_pc_path.ps1` |
| How does conversion logic work? (Mac, legacy shell) | `paste_mac_path.sh` / `copy_pc_path.sh` + `pcpath_common.sh` |
| How does conversion logic work? (Mac, new extension) | `macapp/Sources/PCPathKit/PathConverter.swift` |
| How does conversion logic work? (Web) | `web/PCPath_v1.5.0.html` → `normalizeMacLike` / `macToPC` / `pcToMac` |
| Why does multi-select work? | `pcpath_launch.vbs` + `MultiSelectModel=Player` regs in `install.ps1` |
| Why no PowerShell window flash? | `pcpath_launch.vbs` (`WScript.Shell.Run cmd, 0, False`) |
| How does the installer detect updates? | `PCPathInstall.nsi` → `.onInit` reads `DisplayVersion` |
| How do I bump the Windows version? | Run `sync.ps1` (auto) or edit `PCPATH_VERSION` in `PCPathInstall.nsi` |
| IT-facing install doc | `_Out/PCPath/PCPath IT Setup Instructions.txt` (canonical) |
