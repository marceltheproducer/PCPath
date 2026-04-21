# PCPath Installer UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Polish the macOS and Windows installers with step-by-step output, a self-test, an install log, and add standalone verify scripts for IT.

**Architecture:** Five targeted file changes — two installer rewrites, one Kandji script update, and two new verify scripts. No new dependencies. The conversion logic in `pcpath_common.sh` / `pcpath_common.ps1` is reused directly by both installers and verify scripts for the self-test.

**Tech Stack:** Bash (macOS), PowerShell 5.1 (Windows), `osascript` for macOS notifications, `open` URL scheme for System Settings deep-link.

---

## File Map

| File | Action | What it does |
|---|---|---|
| `install.sh` | Modify | Numbered steps, Settings handoff, self-test, install log |
| `windows/install.ps1` | Modify | Numbered steps, self-test, install log |
| `kandji/user_setup.sh` | Modify | First-install notification, install log |
| `verify.sh` | Create | macOS verification script for IT |
| `windows/verify.ps1` | Create | Windows verification script for IT |

---

## Task 1: Update `install.sh`

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Replace `install.sh` with the following**

```bash
#!/bin/bash
# PCPath Installer for macOS
# Installs Quick Actions and sets up the config file.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.pcpath"
SERVICES_DIR="$HOME/Library/Services"
CONFIG_FILE="$HOME/.pcpath_mappings"
LOG_FILE="$INSTALL_DIR/install.log"
STEP=0
TOTAL=4

_step() {
    STEP=$((STEP + 1))
    printf "  [%d/%d] %-35s" "$STEP" "$TOTAL" "$1"
}

echo "Installing PCPath..."
echo ""

_step "Creating install directory..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$SERVICES_DIR"
echo "done"

_step "Copying scripts..."
cp "$SCRIPT_DIR/pcpath_common.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/copy_pc_path.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/paste_mac_path.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/pcpath_common.sh"
chmod +x "$INSTALL_DIR/copy_pc_path.sh"
chmod +x "$INSTALL_DIR/paste_mac_path.sh"
echo "done"

_step "Installing Quick Actions..."
cp -R "$SCRIPT_DIR/Copy as PC Path.workflow" "$SERVICES_DIR/"
cp -R "$SCRIPT_DIR/Convert to Mac Path.workflow" "$SERVICES_DIR/"
echo "done"

_step "Writing config..."
if [[ ! -f "$CONFIG_FILE" ]]; then
    cp "$SCRIPT_DIR/pcpath_mappings.default" "$CONFIG_FILE"
    echo "done"
else
    echo "done (already existed, kept)"
fi

echo ""

# Record install
echo "$(date -u +"%Y-%m-%dT%H:%M:%S") PCPath installed via manual installer" >> "$LOG_FILE"

# System Settings handoff
echo "Action required: enable Quick Actions in System Settings"
echo "  -> Finder -> check \"Copy as PC Path\" and \"Convert to Mac Path\""
echo ""
sleep 1
open "x-apple.systempreferences:com.apple.ExtensionsPreferences" 2>/dev/null || \
    echo "  (Open System Settings manually -> search for \"Extensions\" -> select Finder)"
echo ""

# Self-test
printf "Running self-test...\n"
source "$INSTALL_DIR/pcpath_common.sh"
pcpath_load_mappings
if [[ ${#vol_names[@]} -eq 0 ]]; then
    printf "  Warning: no mappings found in config -- skipping conversion test\n"
else
    _vol="${vol_names[0]}"
    _letter="${drive_letters[0]}"
    _input="/Volumes/${_vol}/Projects/test.mp4"
    _prefix="/Volumes/${_vol}/"
    _remainder="${_input:${#_prefix}}"
    _result="${_letter}:\\${_remainder}"
    _result="${_result//\//\\}"
    printf "  Input:   %s\n" "$_input"
    printf "  Output:  %s\n" "$_result"
    if [[ "$_result" == "${_letter}:"* ]]; then
        echo "OK  Conversion working"
    else
        echo "FAIL  Conversion failed -- check $CONFIG_FILE"
        exit 1
    fi
fi

echo ""
echo "OK  PCPath installed successfully"
echo ""
echo "Context menu actions:"
echo "  Copy as PC Path      Right-click a file or folder in Finder -> Quick Actions"
echo "  Convert to Mac Path  Right-click a file or folder in Finder -> Quick Actions"
echo ""
echo "Drive mappings: $CONFIG_FILE"
echo "Edit that file to add or change volume-to-drive-letter mappings."
```

- [ ] **Step 2: Test the output format**

Run from the repo root on a Mac:
```bash
bash install.sh
```

Expected terminal output (exact shape):
```
Installing PCPath...

  [1/4] Creating install directory...    done
  [2/4] Copying scripts...               done
  [3/4] Installing Quick Actions...      done
  [4/4] Writing config...                done (already existed, kept)

Action required: enable Quick Actions in System Settings
  -> Finder -> check "Copy as PC Path" and "Convert to Mac Path"

Running self-test...
  Input:   /Volumes/CONTENT/Projects/test.mp4
  Output:  K:\Projects\test.mp4
OK  Conversion working

OK  PCPath installed successfully
...
```

System Settings should open automatically to the Extensions pane.

- [ ] **Step 3: Verify log was written**

```bash
cat ~/.pcpath/install.log
```

Expected: a line like `2026-04-21T14:30:00 PCPath installed via manual installer`

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "feat: polish install.sh with numbered steps, Settings handoff, self-test, and install log"
```

---

## Task 2: Update `windows/install.ps1`

**Files:**
- Modify: `windows/install.ps1`

- [ ] **Step 1: Replace `windows/install.ps1` with the following**

```powershell
# PCPath Installer for Windows
# Adds context menu entries for path conversion.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallDir = "$env:USERPROFILE\.pcpath"
$ConfigFile = "$env:USERPROFILE\.pcpath_mappings"
$LogFile    = "$InstallDir\install.log"
$Step       = 0
$Total      = 4

function Write-Step {
    param([string]$Label)
    $script:Step++
    Write-Host ("  [{0}/{1}] {2,-35}" -f $script:Step, $script:Total, $Label) -NoNewline
}

Write-Host "Installing PCPath..."
Write-Host ""

Write-Step "Creating install directory..."
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Write-Host "done"

Write-Step "Copying scripts..."
Copy-Item "$ScriptDir\pcpath_common.ps1"        "$InstallDir\" -Force
Copy-Item "$ScriptDir\copy_mac_path.ps1"        "$InstallDir\" -Force
Copy-Item "$ScriptDir\convert_to_pc_path.ps1"   "$InstallDir\" -Force
Write-Host "done"

Write-Step "Adding context menu entries..."
$RegPathFile           = "HKCU:\Software\Classes\*\shell\CopyAsMacPath"
$RegPathDir            = "HKCU:\Software\Classes\Directory\shell\CopyAsMacPath"
$RegPathBg             = "HKCU:\Software\Classes\Directory\Background\shell\CopyAsMacPath"
$RegPathConvertBg      = "HKCU:\Software\Classes\Directory\Background\shell\ConvertToPCPath"
$RegPathConvertDesktop = "HKCU:\Software\Classes\DesktopBackground\shell\ConvertToPCPath"
$AllRegPaths = @($RegPathFile, $RegPathDir, $RegPathBg, $RegPathConvertBg, $RegPathConvertDesktop)

$PsCmd        = "powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\copy_mac_path.ps1`""
$ConvertPsCmd = "powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\convert_to_pc_path.ps1`""

try {
    New-Item -Path "$RegPathFile\command" -Force | Out-Null
    Set-ItemProperty -Path $RegPathFile -Name "(Default)" -Value "Copy as Mac Path"
    Set-ItemProperty -Path $RegPathFile -Name "Icon"      -Value "shell32.dll,134"
    Set-ItemProperty -Path "$RegPathFile\command" -Name "(Default)" -Value "$PsCmd `"%1`""

    New-Item -Path "$RegPathDir\command" -Force | Out-Null
    Set-ItemProperty -Path $RegPathDir -Name "(Default)" -Value "Copy as Mac Path"
    Set-ItemProperty -Path $RegPathDir -Name "Icon"      -Value "shell32.dll,134"
    Set-ItemProperty -Path "$RegPathDir\command" -Name "(Default)" -Value "$PsCmd `"%V`""

    New-Item -Path "$RegPathBg\command" -Force | Out-Null
    Set-ItemProperty -Path $RegPathBg -Name "(Default)" -Value "Copy as Mac Path"
    Set-ItemProperty -Path $RegPathBg -Name "Icon"      -Value "shell32.dll,134"
    Set-ItemProperty -Path "$RegPathBg\command" -Name "(Default)" -Value "$PsCmd `"%V`""

    New-Item -Path "$RegPathConvertBg\command" -Force | Out-Null
    Set-ItemProperty -Path $RegPathConvertBg -Name "(Default)" -Value "Convert to PC Path"
    Set-ItemProperty -Path $RegPathConvertBg -Name "Icon"      -Value "shell32.dll,134"
    Set-ItemProperty -Path "$RegPathConvertBg\command" -Name "(Default)" -Value $ConvertPsCmd

    New-Item -Path "$RegPathConvertDesktop\command" -Force | Out-Null
    Set-ItemProperty -Path $RegPathConvertDesktop -Name "(Default)" -Value "Convert to PC Path"
    Set-ItemProperty -Path $RegPathConvertDesktop -Name "Icon"      -Value "shell32.dll,134"
    Set-ItemProperty -Path "$RegPathConvertDesktop\command" -Name "(Default)" -Value $ConvertPsCmd
} catch {
    Write-Host "Error creating registry entries: $_" -ForegroundColor Red
    Write-Host "Rolling back..." -ForegroundColor Yellow
    foreach ($path in $AllRegPaths) {
        if (Test-Path $path) { Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue }
    }
    throw
}
Write-Host "done"

Write-Step "Writing config..."
$DefaultConfig = Join-Path (Split-Path -Parent $ScriptDir) "pcpath_mappings.default"
if (-not (Test-Path $ConfigFile)) {
    Copy-Item $DefaultConfig $ConfigFile
    Write-Host "done"
} else {
    Write-Host "done (already existed, kept)"
}

Write-Host ""

# Record install
Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss') PCPath installed via manual installer" -Encoding UTF8

# Self-test
Write-Host "Running self-test..."
. "$InstallDir\pcpath_common.ps1"
$DriveToVol = Get-PCPathMappings -DriveToVolume
if ($DriveToVol.Count -eq 0) {
    Write-Host "  Warning: no mappings found -- skipping conversion test"
} else {
    $TestLetter = @($DriveToVol.Keys)[0]
    $TestVol    = $DriveToVol[$TestLetter]
    $TestInput  = "${TestLetter}:\Projects\test.mp4"
    $MacPath    = "/Volumes/$TestVol/Projects/test.mp4"
    Write-Host "  Input:   $TestInput"
    Write-Host "  Output:  $MacPath"
    if ($MacPath -like "/Volumes/*") {
        Write-Host "OK  Conversion working"
    } else {
        Write-Host "FAIL  Conversion failed -- check $ConfigFile" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "OK  PCPath installed successfully"
Write-Host ""
Write-Host "Context menu actions:"
Write-Host "  Copy as Mac Path     Right-click any file or folder"
Write-Host "  Convert to PC Path   Right-click empty space in a folder or desktop"
Write-Host ""
Write-Host "Drive mappings: $ConfigFile"
Write-Host "Edit that file to add or change volume-to-drive-letter mappings."
```

- [ ] **Step 2: Test the output format**

Run from the `windows\` directory in PowerShell:
```powershell
.\install.ps1
```

Expected terminal output (exact shape):
```
Installing PCPath...

  [1/4] Creating install directory...    done
  [2/4] Copying scripts...               done
  [3/4] Adding context menu entries...   done
  [4/4] Writing config...                done (already existed, kept)

Running self-test...
  Input:   K:\Projects\test.mp4
  Output:  /Volumes/CONTENT/Projects/test.mp4
OK  Conversion working

OK  PCPath installed successfully
...
```

- [ ] **Step 3: Verify log was written**

```powershell
Get-Content "$env:USERPROFILE\.pcpath\install.log"
```

Expected: a line like `2026-04-21T14:30:00 PCPath installed via manual installer`

- [ ] **Step 4: Commit**

```bash
git add windows/install.ps1
git commit -m "feat: polish install.ps1 with numbered steps, self-test, and install log"
```

---

## Task 3: Update `kandji/user_setup.sh`

**Files:**
- Modify: `kandji/user_setup.sh`

- [ ] **Step 1: Replace `kandji/user_setup.sh` with the following**

```bash
#!/bin/bash
# PCPath per-user setup — runs at login via LaunchAgent
# Copies workflows and scripts into the current user's home directory.

set -e

SYSTEM_DIR="/usr/local/pcpath"
INSTALL_DIR="$HOME/.pcpath"
SERVICES_DIR="$HOME/Library/Services"
CONFIG_FILE="$HOME/.pcpath_mappings"
STAMP_FILE="$INSTALL_DIR/.installed_version"
LOG_FILE="$INSTALL_DIR/install.log"

VERSION_FILE="$SYSTEM_DIR/.version"
INSTALLED_VERSION=""
[[ -f "$STAMP_FILE" ]] && INSTALLED_VERSION=$(cat "$STAMP_FILE" 2>/dev/null)
CURRENT_VERSION=""
[[ -f "$VERSION_FILE" ]] && CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null)

# Skip if already set up for this version
if [[ -n "$CURRENT_VERSION" && "$INSTALLED_VERSION" == "$CURRENT_VERSION" ]]; then
    exit 0
fi

# Track whether this is a true first install (no prior stamp file)
IS_FIRST_INSTALL=false
[[ -z "$INSTALLED_VERSION" ]] && IS_FIRST_INSTALL=true

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$SERVICES_DIR"

# Copy scripts
cp "$SYSTEM_DIR/pcpath_common.sh" "$INSTALL_DIR/"
cp "$SYSTEM_DIR/copy_pc_path.sh" "$INSTALL_DIR/"
cp "$SYSTEM_DIR/paste_mac_path.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/pcpath_common.sh"
chmod +x "$INSTALL_DIR/copy_pc_path.sh"
chmod +x "$INSTALL_DIR/paste_mac_path.sh"

# Install workflows
cp -R "$SYSTEM_DIR/Copy as PC Path.workflow" "$SERVICES_DIR/"
cp -R "$SYSTEM_DIR/Convert to Mac Path.workflow" "$SERVICES_DIR/"

# Create default config if it doesn't exist
if [[ ! -f "$CONFIG_FILE" ]]; then
    cp "$SYSTEM_DIR/pcpath_mappings.default" "$CONFIG_FILE"
fi

# Stamp the installed version
if [[ -n "$CURRENT_VERSION" ]]; then
    echo "$CURRENT_VERSION" > "$STAMP_FILE"
fi

# Write install log
echo "$(date -u +"%Y-%m-%dT%H:%M:%S") PCPath ${CURRENT_VERSION:-unknown} installed via MDM" >> "$LOG_FILE"

# Notify user on first install to enable Quick Actions in System Settings
if [[ "$IS_FIRST_INSTALL" == true ]]; then
    osascript -e 'display notification "Open System Settings -> Extensions -> Finder to enable PCPath Quick Actions." with title "PCPath Installed"' 2>/dev/null || true
fi
```

- [ ] **Step 2: Verify the diff is correct**

```bash
git diff kandji/user_setup.sh
```

Confirm the diff shows:
- `LOG_FILE` variable added near the top
- `IS_FIRST_INSTALL` flag set after `INSTALLED_VERSION` is read
- Install log `echo` added after the version stamp
- `osascript` notification block added at the end
- No other lines changed

- [ ] **Step 3: Commit**

```bash
git add kandji/user_setup.sh
git commit -m "feat: add first-install notification and install log to user_setup.sh"
```

---

## Task 4: Create `verify.sh`

**Files:**
- Create: `verify.sh`

- [ ] **Step 1: Create `verify.sh` with the following content**

```bash
#!/bin/bash
# PCPath Verification — checks that PCPath is correctly installed on macOS.
# Exit code: 0 = all checks passed, 1 = one or more checks failed.

INSTALL_DIR="$HOME/.pcpath"
SERVICES_DIR="$HOME/Library/Services"
CONFIG_FILE="$HOME/.pcpath_mappings"
LOG_FILE="$INSTALL_DIR/install.log"

PASS=0
FAIL=0
WARN=0

_pass() { printf "  [OK] %s\n" "$1"; PASS=$((PASS + 1)); }
_fail() { printf "  [FAIL] %s\n" "$1"; FAIL=$((FAIL + 1)); }
_warn() { printf "  [!!] %s\n" "$1"; WARN=$((WARN + 1)); }

printf "\nPCPath Verification\n"
printf -- "---------------------------------------\n"

# 1. Scripts present and executable
SCRIPTS=("pcpath_common.sh" "copy_pc_path.sh" "paste_mac_path.sh")
all_scripts=true
for s in "${SCRIPTS[@]}"; do
    [[ ! -x "$INSTALL_DIR/$s" ]] && all_scripts=false
done
if [[ "$all_scripts" == true ]]; then
    _pass "Scripts installed at $INSTALL_DIR/"
else
    _fail "Scripts missing or not executable at $INSTALL_DIR/"
    printf "       Run install.sh to fix this.\n"
fi

# 2. Config file with at least one valid mapping
if [[ -f "$CONFIG_FILE" ]]; then
    mapping_count=0
    while IFS= read -r line; do
        line="${line//$'\r'/}"
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        mapping_count=$((mapping_count + 1))
    done < "$CONFIG_FILE"
    if [[ "$mapping_count" -gt 0 ]]; then
        _pass "Config file exists ($mapping_count mapping(s))"
    else
        _fail "Config file exists but has no valid mappings"
        printf "       Edit %s to add mappings (format: VOLUME=K)\n" "$CONFIG_FILE"
    fi
else
    _fail "Config file not found at $CONFIG_FILE"
    printf "       Run install.sh or create the file manually.\n"
fi

# 3. Quick Action workflows installed
WORKFLOWS=("Copy as PC Path.workflow" "Convert to Mac Path.workflow")
all_workflows=true
for w in "${WORKFLOWS[@]}"; do
    [[ ! -d "$SERVICES_DIR/$w" ]] && all_workflows=false
done
if [[ "$all_workflows" == true ]]; then
    _pass "Quick Actions installed in $SERVICES_DIR/"
else
    _fail "Quick Actions missing from $SERVICES_DIR/"
    printf "       Run install.sh to fix this.\n"
fi

# 4. Quick Action enabled state (cannot be read programmatically)
_warn "Quick Action enable state unknown -- confirm in System Settings -> Extensions -> Finder"

# 5. Install log (informational, not required)
if [[ -f "$LOG_FILE" ]]; then
    log_line=$(tail -1 "$LOG_FILE" 2>/dev/null)
    _pass "Install log: $log_line"
fi

# 6. Self-test: live conversion
if [[ -x "$INSTALL_DIR/pcpath_common.sh" ]]; then
    source "$INSTALL_DIR/pcpath_common.sh"
    pcpath_load_mappings
    if [[ ${#vol_names[@]} -gt 0 ]]; then
        _vol="${vol_names[0]}"
        _letter="${drive_letters[0]}"
        _input="/Volumes/${_vol}/Projects/test.mp4"
        _prefix="/Volumes/${_vol}/"
        _remainder="${_input:${#_prefix}}"
        _result="${_letter}:\\${_remainder}"
        _result="${_result//\//\\}"
        if [[ "$_result" == "${_letter}:"* ]]; then
            _pass "Self-test passed: /Volumes/${_vol} -> ${_letter}:\\"
        else
            _fail "Self-test failed: unexpected output from conversion"
        fi
    else
        _warn "No mappings loaded -- self-test skipped"
    fi
fi

printf "\n"
if [[ "$FAIL" -gt 0 ]]; then
    printf "%d issue(s) found. See above.\n" "$FAIL"
    exit 1
elif [[ "$WARN" -gt 0 ]]; then
    printf "All critical checks passed. %d item(s) need manual confirmation.\n" "$WARN"
    exit 0
else
    printf "All checks passed.\n"
    exit 0
fi
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x verify.sh
```

- [ ] **Step 3: Test on a Mac with PCPath already installed**

```bash
bash verify.sh
```

Expected output:
```
PCPath Verification
---------------------------------------
  [OK] Scripts installed at /Users/<you>/.pcpath/
  [OK] Config file exists (4 mapping(s))
  [OK] Quick Actions installed in /Users/<you>/Library/Services/
  [!!] Quick Action enable state unknown -- confirm in System Settings -> Extensions -> Finder
  [OK] Install log: 2026-04-21T14:30:00 PCPath installed via manual installer
  [OK] Self-test passed: /Volumes/CONTENT -> K:\

All critical checks passed. 1 item(s) need manual confirmation.
```

Exit code should be `0` (warnings do not fail). Verify with:
```bash
echo $?
# Expected: 0
```

- [ ] **Step 4: Test on a Mac with PCPath NOT installed**

Temporarily rename the install dir:
```bash
mv ~/.pcpath ~/.pcpath.bak
bash verify.sh
echo $?
mv ~/.pcpath.bak ~/.pcpath
```

Expected: multiple `[FAIL]` lines and exit code `1`.

- [ ] **Step 5: Commit**

```bash
git add verify.sh
git commit -m "feat: add verify.sh for macOS PCPath installation checks"
```

---

## Task 5: Create `windows/verify.ps1`

**Files:**
- Create: `windows/verify.ps1`

- [ ] **Step 1: Create `windows/verify.ps1` with the following content**

```powershell
# PCPath Verification — checks that PCPath is correctly installed on Windows.
# Exit code: 0 = all checks passed, 1 = one or more checks failed.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$InstallDir = "$env:USERPROFILE\.pcpath"
$ConfigFile = "$env:USERPROFILE\.pcpath_mappings"
$LogFile    = "$InstallDir\install.log"

$Pass = 0
$Fail = 0

function Write-Pass { param([string]$Msg) Write-Host "  [OK]   $Msg"; $script:Pass++ }
function Write-Fail { param([string]$Msg) Write-Host "  [FAIL] $Msg"; $script:Fail++ }

Write-Host ""
Write-Host "PCPath Verification"
Write-Host "---------------------------------------"

# 1. Scripts present
$Scripts   = @("pcpath_common.ps1", "copy_mac_path.ps1", "convert_to_pc_path.ps1")
$AllPresent = $true
foreach ($s in $Scripts) {
    if (-not (Test-Path (Join-Path $InstallDir $s))) { $AllPresent = $false }
}
if ($AllPresent) {
    Write-Pass "Scripts installed at $InstallDir\"
} else {
    Write-Fail "Scripts missing at $InstallDir\ -- run install.ps1 to fix"
}

# 2. Config file with at least one valid mapping
if (Test-Path $ConfigFile) {
    $lines = Get-Content $ConfigFile -Encoding UTF8 |
             Where-Object { $_ -and -not $_.TrimStart().StartsWith('#') }
    $count = ($lines | Measure-Object).Count
    if ($count -gt 0) {
        Write-Pass "Config file exists ($count mapping(s))"
    } else {
        Write-Fail "Config file exists but has no valid mappings -- edit $ConfigFile"
    }
} else {
    Write-Fail "Config file not found at $ConfigFile -- run install.ps1 to fix"
}

# 3. Registry entries (all 5 required)
$RegPaths = @(
    "HKCU:\Software\Classes\*\shell\CopyAsMacPath",
    "HKCU:\Software\Classes\Directory\shell\CopyAsMacPath",
    "HKCU:\Software\Classes\Directory\Background\shell\CopyAsMacPath",
    "HKCU:\Software\Classes\Directory\Background\shell\ConvertToPCPath",
    "HKCU:\Software\Classes\DesktopBackground\shell\ConvertToPCPath"
)
$Present = ($RegPaths | Where-Object { Test-Path $_ }).Count
if ($Present -eq $RegPaths.Count) {
    Write-Pass "Registry entries present ($Present/$($RegPaths.Count))"
} else {
    Write-Fail "Registry entries incomplete ($Present/$($RegPaths.Count)) -- run install.ps1 to fix"
}

# 4. Install log (informational, not required)
if (Test-Path $LogFile) {
    $LogLine = Get-Content $LogFile -Tail 1 -ErrorAction SilentlyContinue
    Write-Pass "Install log: $LogLine"
}

# 5. Self-test: live conversion
$CommonScript = Join-Path $InstallDir "pcpath_common.ps1"
if (Test-Path $CommonScript) {
    . $CommonScript
    $DriveToVol = Get-PCPathMappings -DriveToVolume
    if ($DriveToVol.Count -gt 0) {
        $TestLetter = @($DriveToVol.Keys)[0]
        $TestVol    = $DriveToVol[$TestLetter]
        $TestInput  = "${TestLetter}:\Projects\test.mp4"
        $MacPath    = "/Volumes/$TestVol/Projects/test.mp4"
        if ($MacPath -like "/Volumes/*") {
            Write-Pass "Self-test passed: ${TestLetter}:\ -> /Volumes/$TestVol"
        } else {
            Write-Fail "Self-test failed: unexpected output from conversion"
        }
    } else {
        Write-Host "  [!!]  No mappings loaded -- self-test skipped"
    }
}

Write-Host ""
if ($Fail -gt 0) {
    Write-Host "$Fail issue(s) found. See above."
    exit 1
} else {
    Write-Host "All checks passed."
    exit 0
}
```

- [ ] **Step 2: Test on a Windows machine with PCPath already installed**

```powershell
.\windows\verify.ps1
```

Expected output:
```
PCPath Verification
---------------------------------------
  [OK]   Scripts installed at C:\Users\<you>\.pcpath\
  [OK]   Config file exists (4 mapping(s))
  [OK]   Registry entries present (5/5)
  [OK]   Install log: 2026-04-21T14:30:00 PCPath installed via manual installer
  [OK]   Self-test passed: K:\ -> /Volumes/CONTENT

All checks passed.
```

Exit code should be 0:
```powershell
$LASTEXITCODE
# Expected: 0
```

- [ ] **Step 3: Test with PCPath NOT installed**

```powershell
# Temporarily rename install dir
Rename-Item "$env:USERPROFILE\.pcpath" "$env:USERPROFILE\.pcpath.bak"
.\windows\verify.ps1
$LASTEXITCODE  # Expected: 1
Rename-Item "$env:USERPROFILE\.pcpath.bak" "$env:USERPROFILE\.pcpath"
```

Expected: multiple `[FAIL]` lines and exit code `1`.

- [ ] **Step 4: Commit**

```bash
git add windows/verify.ps1
git commit -m "feat: add verify.ps1 for Windows PCPath installation checks"
```

---

## Task 6: Final check and wrap-up

- [ ] **Step 1: Verify all five files are changed/created**

```bash
git log --oneline -5
```

Expected: five commits from this feature (Tasks 1-5 each have one commit).

- [ ] **Step 2: Smoke test `verify.sh` exit code in a clean state**

```bash
bash verify.sh; echo "Exit: $?"
```

Expected: exit code `0` with at most one `[!!]` warning (the Quick Actions enable-state warning — this is always present and expected).

- [ ] **Step 3: Confirm `install.sh` is idempotent (safe to re-run)**

```bash
bash install.sh
```

Expected: step 4 should say `done (already existed, kept)` since config is already present. No errors.

- [ ] **Step 4: Final commit if any cleanup needed, then done**

```bash
git log --oneline -6
```
