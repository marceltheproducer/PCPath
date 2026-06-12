# PCPath — Handoff / Context

Last touched: 2026-05-15. Owner: Marcel Perez.

PCPath converts file paths between Mac (`/Volumes/...`) and Windows (`K:\...`)
formats via right-click context menu actions on both OSes, plus a no-install
web converter for everything else.

---

## Current versions

| Surface  | Version | Notes |
|----------|---------|-------|
| Windows installer | **2.3** (build stamp `YYYY.MM.DD.HHMM`) | NSIS exe, auto-updates, no PowerShell required |
| Web converter     | **v1.4.0** (`PCPath_v1.4.0.html`) | Self-contained, dark mode, inline-SVG favicon |
| Mac install       | No version stamp (manual `install.sh` / curl one-liner) | One-shot script + `~/.pcpath/install.log` |

Bump Windows by editing `!define PCPATH_VERSION "2.3"` in `windows/PCPathInstall.nsi`
(or just run `sync.ps1` — it auto-bumps the minor).

---

## Right-click verbs (feature parity)

| Windows verb | Mac equivalent | Notes |
|---|---|---|
| Copy as Mac Path | Copy as PC Path (reverse direction) | Multi-select → CRLF-joined |
| Copy as Path     | Built into Finder (Option+right-click → "Copy as Pathname") | Windows path format |
| Copy Names       | Copy Names | Filenames only, one per line |
| Convert to PC Path (background / desktop) | Convert to Mac Path | Reads clipboard |

Path-shape coverage (all three implementations match — Windows ps1, Mac sh, web JS):
- `/Volumes/<vol>/...` (canonical)
- `smb://server/share/...` (bare hostname OR FQDN, URL-decoded)
- `\Volumes\X\...`, `\\Volumes\X\...`, `/volumes/X/...` (case + slash variants)

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
`G:\_library\Tech\DevOps\PCPath\PCPathInstall.exe` — double-click. Detects existing installs and shows "Updating: <old> → 2.3".

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
`PCPath_v1.4.0.html` — open in any browser. No install. localStorage-backed mappings.

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
├── Copy as PC Path.workflow/                    # Automator Quick Action bundles
├── Convert to Mac Path.workflow/
├── Copy Names.workflow/
├── kandji/                                      # MDM build + per-user setup
├── web/PCPath_v1.4.0.html                       # standalone web converter
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
```

Lives at `~/.pcpath_mappings` (Mac) / `%USERPROFILE%\.pcpath_mappings` (Windows).
Edit per machine; case-insensitive lookup so `Edit` finds `EDIT`.

---

## Recent work (this session)

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

- **macOS enable step** — Apple requires the user to check Quick Actions in System Settings. No automation possible (Privacy & Security model).
- **Mac install has no version stamp** — `install.log` exists but no `version.txt` equivalent. Low priority; pkg path (Kandji) has version metadata.
- **Pre-existing dirty files in git** that this session didn't touch: `kandji/build_pkg.sh`, `kandji/uninstall_mdm.sh`, `pcpath_common.sh`, `remote_install.sh`, `Convert to Mac Path.workflow/Contents/Info.plist`. They're deployed but uncommitted. Inspect with `git diff` and decide before next release.
- **The G:\ install location** — sometimes `PCPathInstall.exe` is locked there during a re-sync if a previous installer window is still open. `sync.ps1` warns and continues; user just closes the dialog and re-runs.

---

## Where to look first

| Question | File |
|---|---|
| How does conversion logic work? (Windows) | `windows/convert_to_pc_path.ps1` |
| How does conversion logic work? (Mac) | `paste_mac_path.sh` |
| How does conversion logic work? (Web) | `web/PCPath_v1.4.0.html` → `normalizeMacLike` / `macToPC` / `pcToMac` |
| Why does multi-select work? | `pcpath_launch.vbs` + `MultiSelectModel=Player` regs in `install.ps1` |
| Why no PowerShell window flash? | `pcpath_launch.vbs` (`WScript.Shell.Run cmd, 0, False`) |
| How does the installer detect updates? | `PCPathInstall.nsi` → `.onInit` reads `DisplayVersion` |
| How do I bump the Windows version? | Run `sync.ps1` (auto) or edit `PCPATH_VERSION` in `PCPathInstall.nsi` |
| IT-facing install doc | `_Out/PCPath/PCPath IT Setup Instructions.txt` (canonical) |
