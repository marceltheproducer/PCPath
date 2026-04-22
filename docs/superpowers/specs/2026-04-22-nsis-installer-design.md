# PCPath NSIS Installer Design

**Date:** 2026-04-22
**Branch:** feature/installer-ux
**Status:** Approved

## Overview

Wrap the PCPath Windows installer as a native NSIS executable (`PCPathInstall.exe`). Users on domain machines double-click it to install; no PowerShell execution policy concerns, no manual script invocation. The exe is pre-built and committed to the repo alongside the source `.nsi` script.

## File Structure

```
windows/
  PCPathInstall.nsi        ← NSIS script (source of truth)
  PCPathInstall.exe        ← pre-built, committed to git
  install.ps1              ← kept as dev/manual fallback
  pcpath_common.ps1
  copy_mac_path.ps1
  convert_to_pc_path.ps1
  uninstall.ps1
  verify.ps1
pcpath_mappings.default    ← bundled into the exe at build time
```

## Installer Behavior

NSIS handles all install steps natively — no PowerShell invoked at install time.

1. Create `$PROFILE\.pcpath\`
2. Copy three runtime scripts there:
   - `pcpath_common.ps1`
   - `copy_mac_path.ps1`
   - `convert_to_pc_path.ps1`
3. Write `$PROFILE\.pcpath_mappings` from the bundled default **only if the file does not already exist** — preserves user customizations on reinstall
4. Write five HKCU registry keys (matches existing `install.ps1` behavior):
   - `HKCU\Software\Classes\*\shell\CopyAsMacPath` — files
   - `HKCU\Software\Classes\Directory\shell\CopyAsMacPath` — folders
   - `HKCU\Software\Classes\Directory\Background\shell\CopyAsMacPath` — folder background
   - `HKCU\Software\Classes\Directory\Background\shell\ConvertToPCPath`
   - `HKCU\Software\Classes\DesktopBackground\shell\ConvertToPCPath`
5. Register uninstaller in `HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath`

HKCU does not require elevation; admin credentials are available on target domain machines if ever needed for future HKLM writes.

## UI

Silent-style install — no wizard pages or configuration screens (nothing to configure). Flow:

- Install button → progress bar → finish screen with "PCPath installed successfully."
- MUI2 (Modern UI 2) for standard Windows installer chrome.

## Uninstaller

NSIS generates `uninstall.exe`, placed in `$PROFILE\.pcpath\` and registered in Add/Remove Programs.

Uninstall removes:
- All five HKCU registry keys
- `$PROFILE\.pcpath\` directory and its contents
- Add/Remove Programs entry

Uninstall preserves:
- `$PROFILE\.pcpath_mappings` — user may have customized drive letter mappings

## Build Workflow

Requires [NSIS](https://nsis.sourceforge.io/) installed on the build machine.

```powershell
makensis windows\PCPathInstall.nsi
# outputs windows\PCPathInstall.exe
```

Rebuild and commit the exe whenever any bundled script changes:
- `windows/pcpath_common.ps1`
- `windows/copy_mac_path.ps1`
- `windows/convert_to_pc_path.ps1`
- `pcpath_mappings.default`

## Out of Scope

- Code signing (can be added later via `signtool`)
- MDM/Kandji deployment (separate track)
- Machine-wide install (HKLM context menus) — HKCU is sufficient
