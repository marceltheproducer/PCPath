# PCPath for Windows - Convert a Mac path (from clipboard) to a PC path
# Use when a Mac user sends you a path like /Volumes/CONTENT/Projects/video.mp4
# and you need to navigate to K:\Projects\video.mp4
#
# Usage:
#   .\convert_to_pc_path.ps1                  # reads from clipboard
#   .\convert_to_pc_path.ps1 "/Volumes/..."   # reads from argument

param(
    [Parameter(Position=0)]
    [string]$Path
)

$ConfigFile = "$env:USERPROFILE\.pcpath_mappings"

# Build vol name -> drive letter mapping
$VolToDrive = [System.Collections.Hashtable]::new([System.StringComparer]::OrdinalIgnoreCase)
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
            $VolToDrive[$volName] = $driveLetter
        }
    }
}

# Get path from argument or clipboard
if (-not $Path) {
    $Path = Get-Clipboard
}
if (-not $Path) {
    Write-Host "No path provided and clipboard is empty."
    exit 1
}

# Convert each line separately (handles multiline clipboard)
$Results = @()
$Path -split "`n" | ForEach-Object {
    $Line = $_.Trim()
    if (-not $Line) { return }

    if ($Line -match "^/Volumes/([^/]+)(/(.*))?$") {
        $VolName = $Matches[1]
        $Rest = if ($Matches[3]) { $Matches[3] } else { "" }
        $Rest = $Rest -replace "/", "\"

        if ($VolToDrive.ContainsKey($VolName)) {
            $Drive = $VolToDrive[$VolName]
            $Results += "${Drive}:\$Rest"
        } else {
            # Unknown volume — include name so user knows which to map
            $Results += "?($VolName):\$Rest"
        }
    } else {
        # Not a /Volumes/ path, just swap slashes
        $Results += $Line -replace "/", "\"
    }
}

$Output = $Results -join "`n"
$Output | Set-Clipboard
Write-Host "Copied: $Output"
