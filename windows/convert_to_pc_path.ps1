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

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Load shared config
$CommonPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "pcpath_common.ps1"
. $CommonPath

$VolToDrive = Get-PCPathMappings

# Get path from argument or clipboard
if (-not $Path) {
    $Path = Get-Clipboard
}
if (-not $Path) {
    Write-Host "No path provided and clipboard is empty."
    exit 1
}

# Convert each line separately (handles multiline clipboard)
$ResultList = [System.Collections.Generic.List[string]]::new()
$Path -split "`n" | ForEach-Object {
    $Line = $_.Trim()
    if (-not $Line) { return }

    if ($Line -match "^/Volumes/([^/]+)(/(.*))?$") {
        $VolName = $Matches[1]
        $Rest = if ($Matches[3]) { $Matches[3] } else { "" }
        $Rest = $Rest -replace "/", "\"

        if ($VolToDrive.ContainsKey($VolName)) {
            $Drive = $VolToDrive[$VolName]
            $ResultList.Add($Drive + ':' + '\' + $Rest)
        } else {
            # Unknown volume — include name so user knows which to map
            $ResultList.Add('?(' + $VolName + '):\' + $Rest)
        }
    } else {
        # Not a /Volumes/ path, just swap slashes
        $ResultList.Add(($Line -replace '/', '\'))
    }
}

$Output = $ResultList -join "`n"
$Output | Set-Clipboard
Write-Host "Copied: $Output"
