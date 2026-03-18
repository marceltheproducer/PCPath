# PCPath for Windows - Copy as Mac Path
# Right-click a file or folder to copy the equivalent Mac path to clipboard.
# Reads drive letter mappings from %USERPROFILE%\.pcpath_mappings

param(
    [Parameter(Position=0)]
    [string]$FilePath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Load shared config
$CommonPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "pcpath_common.ps1"
. $CommonPath

$DriveToVol = Get-PCPathMappings -DriveToVolume

if (-not $FilePath) {
    Write-Host "Usage: copy_mac_path.ps1 <file-path>"
    Write-Host "  Or right-click a file and select 'Copy as Mac Path'"
    exit 1
}

# Validate drive-letter path (e.g. C:\..., K:\...)
if ($FilePath -notmatch '^[A-Za-z]:') {
    Write-Host "Not a drive-letter path: $FilePath"
    Write-Host "UNC and relative paths are not supported."
    exit 1
}

# Extract drive letter
$DriveLetter = $FilePath.Substring(0, 1).ToUpper()
$Remainder = ""
if ($FilePath.Length -gt 3) {
    $Remainder = $FilePath.Substring(3)
}

# Convert backslashes to forward slashes
$Remainder = $Remainder -replace "\\", "/"

if ($DriveToVol.ContainsKey($DriveLetter)) {
    $VolumeName = $DriveToVol[$DriveLetter]
    if ($Remainder) {
        $MacPath = "/Volumes/$VolumeName/$Remainder"
    } else {
        $MacPath = "/Volumes/$VolumeName"
    }
} else {
    # Unknown drive letter — include letter so user knows which to map
    if ($Remainder) {
        $MacPath = "/Volumes/?($DriveLetter)/$Remainder"
    } else {
        $MacPath = "/Volumes/?($DriveLetter)"
    }
}

$MacPath | Set-Clipboard
Write-Host "Copied: $MacPath"
