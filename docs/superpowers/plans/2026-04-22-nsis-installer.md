# PCPath NSIS Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the manual PowerShell installer with a double-clickable `PCPathInstall.exe` built from a committed NSIS script, with a rebuild script so the exe stays in sync when any bundled file changes.

**Architecture:** A single NSIS script (`windows/PCPathInstall.nsi`) performs all install steps natively — file copy, registry writes, uninstaller registration — with no PowerShell invoked at install time. A `build_installer.ps1` script regenerates the exe from the repo root. Both the `.nsi` source and the pre-built `.exe` are committed to git.

**Tech Stack:** NSIS 3.x with MUI2 and LogicLib; `makensis` CLI for building.

---

## File Map

| Action | Path | Purpose |
|--------|------|---------|
| Create | `windows/PCPathInstall.nsi` | NSIS source — owns all install logic |
| Create | `windows/build_installer.ps1` | One-click rebuild script |
| Commit | `windows/PCPathInstall.exe` | Pre-built output, committed to git |
| Modify | `.gitattributes` | Mark `.exe` as binary so git doesn't diff it |
| Keep | `windows/install.ps1` | Dev/manual fallback, unchanged |

---

## Task 1: Add `.gitattributes` entry for the exe

**Files:**
- Modify: `.gitattributes` (create if absent)

- [ ] **Step 1: Check if `.gitattributes` exists**

```bash
ls "v:/General Dev/Design/PCPath/.gitattributes" 2>/dev/null || echo "not found"
```

- [ ] **Step 2: Add the binary marker**

Append to `.gitattributes` (create the file if it doesn't exist):

```
windows/PCPathInstall.exe binary
```

- [ ] **Step 3: Commit**

```bash
git add .gitattributes
git commit -m "chore: mark PCPathInstall.exe as binary in gitattributes"
```

---

## Task 2: Write `PCPathInstall.nsi`

**Files:**
- Create: `windows/PCPathInstall.nsi`

The script is run from the **repo root**: `makensis windows\PCPathInstall.nsi`. All `File` paths below are relative to the repo root.

- [ ] **Step 1: Create `windows/PCPathInstall.nsi` with this exact content**

```nsis
; PCPath Installer for Windows
; Build from repo root: makensis windows\PCPathInstall.nsi

!include "MUI2.nsh"
!include "LogicLib.nsh"

;--------------------------------
; Metadata
Name "PCPath"
OutFile "windows\PCPathInstall.exe"
RequestExecutionLevel user
SetCompressor /SOLID lzma
Unicode True

;--------------------------------
; MUI Settings
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_TITLE "PCPath Installed"
!define MUI_FINISHPAGE_TEXT "PCPath is now active.$\r$\n$\r$\nRight-click any file or folder: Copy as Mac Path$\r$\nRight-click empty space or desktop: Convert to PC Path$\r$\n$\r$\nDrive mappings: $PROFILE\.pcpath_mappings"

!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

;--------------------------------
; Install
Section "Install"

    ; Install directory and runtime scripts
    CreateDirectory "$PROFILE\.pcpath"
    SetOutPath "$PROFILE\.pcpath"
    File "windows\pcpath_common.ps1"
    File "windows\copy_mac_path.ps1"
    File "windows\convert_to_pc_path.ps1"

    ; Default config — only write if not present (preserves user customizations on reinstall)
    ${IfNot} ${FileExists} "$PROFILE\.pcpath_mappings"
        SetOutPath "$PROFILE"
        File /oname=".pcpath_mappings" "pcpath_mappings.default"
        SetOutPath "$PROFILE\.pcpath"
    ${EndIf}

    ; Register uninstaller in Add/Remove Programs (HKCU works on Windows 8+)
    WriteUninstaller "$PROFILE\.pcpath\uninstall.exe"
    WriteRegStr  HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath" "DisplayName"     "PCPath"
    WriteRegStr  HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath" "UninstallString" '"$PROFILE\.pcpath\uninstall.exe"'
    WriteRegStr  HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath" "DisplayIcon"     "shell32.dll,134"
    WriteRegStr  HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath" "Publisher"       "CREATE"
    WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath" "NoModify"       1
    WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath" "NoRepair"       1

    ; Context menu: Copy as Mac Path — files
    WriteRegStr HKCU "Software\Classes\*\shell\CopyAsMacPath"          ""     "Copy as Mac Path"
    WriteRegStr HKCU "Software\Classes\*\shell\CopyAsMacPath"          "Icon" "shell32.dll,134"
    WriteRegStr HKCU "Software\Classes\*\shell\CopyAsMacPath\command"  ""     \
        'powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "$PROFILE\.pcpath\copy_mac_path.ps1" "%1"'

    ; Context menu: Copy as Mac Path — directories
    WriteRegStr HKCU "Software\Classes\Directory\shell\CopyAsMacPath"          ""     "Copy as Mac Path"
    WriteRegStr HKCU "Software\Classes\Directory\shell\CopyAsMacPath"          "Icon" "shell32.dll,134"
    WriteRegStr HKCU "Software\Classes\Directory\shell\CopyAsMacPath\command"  ""     \
        'powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "$PROFILE\.pcpath\copy_mac_path.ps1" "%V"'

    ; Context menu: Copy as Mac Path — directory background
    WriteRegStr HKCU "Software\Classes\Directory\Background\shell\CopyAsMacPath"          ""     "Copy as Mac Path"
    WriteRegStr HKCU "Software\Classes\Directory\Background\shell\CopyAsMacPath"          "Icon" "shell32.dll,134"
    WriteRegStr HKCU "Software\Classes\Directory\Background\shell\CopyAsMacPath\command"  ""     \
        'powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "$PROFILE\.pcpath\copy_mac_path.ps1" "%V"'

    ; Context menu: Convert to PC Path — directory background
    WriteRegStr HKCU "Software\Classes\Directory\Background\shell\ConvertToPCPath"          ""     "Convert to PC Path"
    WriteRegStr HKCU "Software\Classes\Directory\Background\shell\ConvertToPCPath"          "Icon" "shell32.dll,134"
    WriteRegStr HKCU "Software\Classes\Directory\Background\shell\ConvertToPCPath\command"  ""     \
        'powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "$PROFILE\.pcpath\convert_to_pc_path.ps1"'

    ; Context menu: Convert to PC Path — desktop background
    WriteRegStr HKCU "Software\Classes\DesktopBackground\shell\ConvertToPCPath"          ""     "Convert to PC Path"
    WriteRegStr HKCU "Software\Classes\DesktopBackground\shell\ConvertToPCPath"          "Icon" "shell32.dll,134"
    WriteRegStr HKCU "Software\Classes\DesktopBackground\shell\ConvertToPCPath\command"  ""     \
        'powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "$PROFILE\.pcpath\convert_to_pc_path.ps1"'

SectionEnd

;--------------------------------
; Uninstall
Section "Uninstall"

    ; Remove context menu registry keys
    DeleteRegKey HKCU "Software\Classes\*\shell\CopyAsMacPath"
    DeleteRegKey HKCU "Software\Classes\Directory\shell\CopyAsMacPath"
    DeleteRegKey HKCU "Software\Classes\Directory\Background\shell\CopyAsMacPath"
    DeleteRegKey HKCU "Software\Classes\Directory\Background\shell\ConvertToPCPath"
    DeleteRegKey HKCU "Software\Classes\DesktopBackground\shell\ConvertToPCPath"

    ; Remove install directory — preserves $PROFILE\.pcpath_mappings intentionally
    RMDir /r "$PROFILE\.pcpath"

    ; Remove Add/Remove Programs entry
    DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath"

SectionEnd
```

- [ ] **Step 2: Commit the .nsi source**

```bash
git add windows/PCPathInstall.nsi
git commit -m "feat: add NSIS installer script"
```

---

## Task 3: Write `build_installer.ps1`

**Files:**
- Create: `windows/build_installer.ps1`

This is the rebuild script the team uses whenever any bundled file changes. It handles running `makensis` from the correct directory regardless of where the script is called from.

- [ ] **Step 1: Create `windows/build_installer.ps1`**

```powershell
# Rebuild PCPathInstall.exe from source.
# Run this whenever pcpath_common.ps1, copy_mac_path.ps1,
# convert_to_pc_path.ps1, or pcpath_mappings.default change.
#
# Requires NSIS: https://nsis.sourceforge.io/

$RepoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $RepoRoot
try {
    makensis "windows\PCPathInstall.nsi"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Built: windows\PCPathInstall.exe" -ForegroundColor Green
    } else {
        Write-Host "Build failed (exit $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}
```

- [ ] **Step 2: Commit**

```bash
git add windows/build_installer.ps1
git commit -m "feat: add build_installer.ps1 for rebuilding NSIS exe"
```

---

## Task 4: Build `PCPathInstall.exe`

**Prerequisites:** NSIS installed on build machine (`winget install NSIS.NSIS` or from https://nsis.sourceforge.io/).

**Files:**
- Create (build output): `windows/PCPathInstall.exe`

- [ ] **Step 1: Verify NSIS is available**

```powershell
makensis /VERSION
```

Expected output: something like `v3.10` — any 3.x version is fine. If command not found, install NSIS first.

- [ ] **Step 2: Build the exe**

Run from the repo root:

```powershell
.\windows\build_installer.ps1
```

Expected output:
```
MakeNSIS v3.xx - Copyright 1999-20xx Contributors
...
Output: "windows\PCPathInstall.exe"
Install: 7 section(s), 0 page(s) (0 transparent, 0 solid)
Built: windows\PCPathInstall.exe
```

- [ ] **Step 3: Verify the exe was created**

```powershell
Get-Item "windows\PCPathInstall.exe" | Select-Object Name, Length, LastWriteTime
```

Expected: file exists, size is roughly 200–400 KB.

- [ ] **Step 4: Commit the exe**

```bash
git add windows/PCPathInstall.exe
git commit -m "feat: add pre-built PCPathInstall.exe"
```

---

## Task 5: Smoke test the installer

Run this on a test machine (or the current machine in a clean user session). Requires the built exe from Task 4.

- [ ] **Step 1: Run the installer**

Double-click `windows\PCPathInstall.exe` — or from PowerShell:

```powershell
Start-Process "windows\PCPathInstall.exe" -Wait
```

Expected: MUI2 installer window opens, shows progress, then a finish screen saying "PCPath Installed".

- [ ] **Step 2: Verify files were installed**

```powershell
Get-ChildItem "$env:USERPROFILE\.pcpath"
```

Expected output — all three files present:
```
copy_mac_path.ps1
convert_to_pc_path.ps1
pcpath_common.ps1
uninstall.exe
```

- [ ] **Step 3: Verify default config was written**

```powershell
Get-Content "$env:USERPROFILE\.pcpath_mappings"
```

Expected: contents of `pcpath_mappings.default` (CONTENT=K, GFX=G, etc.).

- [ ] **Step 4: Verify registry keys**

```powershell
reg query "HKCU\Software\Classes\*\shell\CopyAsMacPath" /ve
reg query "HKCU\Software\Classes\Directory\shell\CopyAsMacPath" /ve
reg query "HKCU\Software\Classes\Directory\Background\shell\CopyAsMacPath" /ve
reg query "HKCU\Software\Classes\Directory\Background\shell\ConvertToPCPath" /ve
reg query "HKCU\Software\Classes\DesktopBackground\shell\ConvertToPCPath" /ve
```

Expected: each query returns `(Default)    REG_SZ    Copy as Mac Path` or `Convert to PC Path`.

- [ ] **Step 5: Verify context menu commands point to correct paths**

```powershell
reg query "HKCU\Software\Classes\*\shell\CopyAsMacPath\command" /ve
```

Expected: value contains `$env:USERPROFILE\.pcpath\copy_mac_path.ps1` (with the actual expanded path, not the variable).

- [ ] **Step 6: Run verify.ps1**

```powershell
powershell -File windows\verify.ps1
```

Expected: all checks pass (files present, registry set, mappings found).

- [ ] **Step 7: Test right-click manually**

Right-click any file in Explorer → confirm "Copy as Mac Path" appears in context menu. Right-click empty space in a folder → confirm "Convert to PC Path" appears.

- [ ] **Step 8: Test the uninstaller**

```powershell
Start-Process "$env:USERPROFILE\.pcpath\uninstall.exe" -Wait
```

Then verify cleanup:

```powershell
# Should return nothing (directory gone)
Test-Path "$env:USERPROFILE\.pcpath"

# Should still exist (preserved intentionally)
Test-Path "$env:USERPROFILE\.pcpath_mappings"

# Registry keys should be gone
reg query "HKCU\Software\Classes\*\shell\CopyAsMacPath" 2>&1
```

Expected: `$PROFILE\.pcpath` is gone, `$PROFILE\.pcpath_mappings` still exists, registry query returns error "The system was unable to find the specified registry key".

- [ ] **Step 9: Re-run installer to confirm reinstall preserves existing mappings**

```powershell
Start-Process "windows\PCPathInstall.exe" -Wait
Get-Content "$env:USERPROFILE\.pcpath_mappings"
```

Expected: mappings file still contains whatever was there before (not overwritten).

---

## Rebuild Checklist

When any of these files change, rebuild and commit the exe:

- `windows/pcpath_common.ps1`
- `windows/copy_mac_path.ps1`
- `windows/convert_to_pc_path.ps1`
- `pcpath_mappings.default`

Rebuild command:
```powershell
.\windows\build_installer.ps1
git add windows/PCPathInstall.exe
git commit -m "build: rebuild PCPathInstall.exe"
```
