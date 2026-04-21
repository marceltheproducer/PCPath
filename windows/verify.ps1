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
$Scripts    = @("pcpath_common.ps1", "copy_mac_path.ps1", "convert_to_pc_path.ps1")
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

# 5. Self-test: round-trip mapping check (verifies config loads and maps correctly)
# Self-test is skipped when the config is missing: Get-PCPathMappings falls back to
# hardcoded defaults, which would produce a misleading OK alongside a config FAIL.
$CommonScript = Join-Path $InstallDir "pcpath_common.ps1"
if ((Test-Path $CommonScript) -and (Test-Path $ConfigFile)) {
    . $CommonScript
    $DriveToVol  = Get-PCPathMappings -DriveToVolume
    $VolToLetter = Get-PCPathMappings
    if ($DriveToVol.Count -gt 0) {
        $TestLetter = @($DriveToVol.Keys)[0]
        $TestVol    = $DriveToVol[$TestLetter]
        $TestInput  = "${TestLetter}:\Projects\test.mp4"
        $MacPath    = "/Volumes/$TestVol/Projects/test.mp4"
        Write-Host "  Windows: $TestInput"
        Write-Host "  Mac:     $MacPath"
        if ($MacPath -like "/Volumes/*" -and $VolToLetter[$TestVol] -eq $TestLetter) {
            Write-Pass "Self-test passed: ${TestLetter}:\ -> /Volumes/$TestVol"
        } else {
            Write-Fail "Self-test failed: mapping round-trip check failed -- check $ConfigFile"
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
