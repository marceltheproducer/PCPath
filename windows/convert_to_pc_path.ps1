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
$StripSuffixes = Get-PCPathStripSuffixes

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
    $Line = Remove-WrappingQuotes ($_.Trim())
    if (-not $Line) { return }

    # smb://server/share/rest  ->  /Volumes/share/rest
    # Handles bare hostnames (smb://calamedia/...) and FQDNs (smb://host.domain.tld/...).
    # The server segment is dropped — only the share name (== volume name) matters.
    # URL-decoded so %20 etc. round-trip cleanly.
    if ($Line -match "^smb://[^/]+/(.*)$") {
        $Line = "/Volumes/" + [uri]::UnescapeDataString($Matches[1])
    }

    # Normalize backslash and case variants of /Volumes/ that people sometimes
    # paste, e.g. \Volumes\X\..., \\Volumes\X\..., /volumes/X/...
    if ($Line -match '^[\\/]+[Vv]olumes[\\/]') {
        $Line = $Line -replace '\\', '/'
        $Line = $Line -replace '^/+[Vv]olumes/', '/Volumes/'
    }

    # \\server\share\rest -> /Volumes/share/rest (host dropped — mirrors smb://,
    # share name == volume name). Device paths (\\?\..., \\.\...) and a bare
    # \\server fall through untouched.
    if ($Line -match '^\\\\([^\\/]+)[\\/](.+)$' -and $Matches[1] -notin @('?', '.')) {
        $Line = '/Volumes/' + ($Matches[2] -replace '\\', '/')
    }

    # Normalize path missing /Volumes/ prefix (e.g. "EDIT/folder/..." -> "/Volumes/EDIT/folder/...")
    if ($Line -notmatch "^/Volumes/") {
        $checkLine = $Line.TrimStart('/')
        foreach ($volName in $VolToDrive.Keys) {
            if ($checkLine -match "^$([regex]::Escape($volName))(/|$)") {
                $Line = "/Volumes/$checkLine"
                break
            }
        }
    }

    if ($Line -match "^/Volumes/([^/]+)(/(.*))?$") {
        $VolName = $Matches[1]
        $Rest = if ($Matches[3]) { $Matches[3] } else { "" }
        $Rest = $Rest -replace "/", "\"

        if ($VolToDrive.ContainsKey($VolName)) {
            $Drive = $VolToDrive[$VolName]
            $ResultList.Add((Remove-SegmentSuffixes ($Drive + ':' + '\' + $Rest) $StripSuffixes))
        } else {
            $Discovered = Resolve-VolumeFallback -Name $VolName -Direction 'VolToLetter'
            if ($Discovered) {
                $ResultList.Add((Remove-SegmentSuffixes ($Discovered + ':' + '\' + $Rest) $StripSuffixes))
            } else {
                # Unknown volume — include name so user knows which to map
                $ResultList.Add((Remove-SegmentSuffixes ('?(' + $VolName + '):\' + $Rest) $StripSuffixes))
            }
        }
    } else {
        # Not a /Volumes/ path, just swap slashes
        $ResultList.Add((Remove-SegmentSuffixes ($Line -replace '/', '\') $StripSuffixes))
    }
}

$Output = $ResultList -join "`n"
$Output | Set-Clipboard
Write-Host "Copied: $Output"
