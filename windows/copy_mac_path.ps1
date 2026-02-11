# PCPath for Windows - Copy as Mac Path
# Right-click a file or folder to copy the equivalent Mac path to clipboard.
# Reads drive letter mappings from %USERPROFILE%\.pcpath_mappings

param(
    [Parameter(Position=0)]
    [string]$FilePath
)

$ConfigFile = "$env:USERPROFILE\.pcpath_mappings"

# Default mappings: drive letter -> volume name
$DriveToVol = @{}
$DefaultMappings = @"
CONTENT=K
GFX=G
EDIT=E
THE_NETWORK=N
"@

$Source = $DefaultMappings
if (Test-Path $ConfigFile) {
    $Source = Get-Content $ConfigFile -Raw
}

$Source -split "`n" | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#")) {
        $parts = $line -split "=", 2
        if ($parts.Count -eq 2) {
            $volName = $parts[0].Trim()
            $driveLetter = $parts[1].Trim().ToUpper()
            $DriveToVol[$driveLetter] = $volName
        }
    }
}

if (-not $FilePath) {
    Write-Host "Usage: copy_mac_path.ps1 <file-path>"
    Write-Host "  Or right-click a file and select 'Copy as Mac Path'"
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
    # Unknown drive letter — use ? as placeholder
    if ($Remainder) {
        $MacPath = "/Volumes/?/$Remainder"
    } else {
        $MacPath = "/Volumes/?"
    }
}

$MacPath | Set-Clipboard
Write-Host "Copied: $MacPath"
