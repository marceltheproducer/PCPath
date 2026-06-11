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
$StripSuffixes = Get-PCPathStripSuffixes

if (-not $FilePath) {
    Write-Host "Usage: copy_mac_path.ps1 <file-path>"
    Write-Host "  Or right-click a file and select 'Copy as Mac Path'"
    exit 1
}

function Convert-OneToMac {
    param([string]$P)
    if ($P -notmatch '^[A-Za-z]:') { return $null }
    $letter    = $P.Substring(0, 1).ToUpper()
    $remainder = if ($P.Length -gt 3) { $P.Substring(3) } else { "" }
    $remainder = $remainder -replace "\\", "/"
    if ($DriveToVol.ContainsKey($letter)) {
        $vol = $DriveToVol[$letter]
        $res = if ($remainder) { "/Volumes/$vol/$remainder" } else { "/Volumes/$vol" }
    } else {
        $res = if ($remainder) { "/Volumes/?($letter)/$remainder" } else { "/Volumes/?($letter)" }
    }
    return (Remove-SegmentSuffixes $res $StripSuffixes)
}

# If invoked from a multi-file selection, Windows runs this command once per
# item — only the last clipboard write would survive. To handle multi-select
# in a single pass we ask Explorer for the current selection that includes
# the clicked path. If no Explorer match (e.g. invoked on a folder via the
# Directory shell verb, or from a non-Explorer caller), fall back to the
# single clicked path.
function Get-ExplorerSelectionPaths {
    param([string]$ClickedPath)
    try {
        $shell = New-Object -ComObject Shell.Application
        $clickedFull = [IO.Path]::GetFullPath($ClickedPath)
        foreach ($w in $shell.Windows()) {
            try {
                $doc = $w.Document
                if (-not $doc) { continue }
                $sel = $doc.SelectedItems()
                if (-not $sel -or $sel.Count -eq 0) { continue }
                $paths = @($sel | ForEach-Object { $_.Path })
                foreach ($p in $paths) {
                    if ($p -and ([IO.Path]::GetFullPath($p) -ieq $clickedFull)) {
                        return ,$paths
                    }
                }
            } catch { continue }
        }
    } catch { }
    return ,@($ClickedPath)
}

$paths = Get-ExplorerSelectionPaths -ClickedPath $FilePath

$results = New-Object System.Collections.Generic.List[string]
foreach ($p in $paths) {
    $mac = Convert-OneToMac -P $p
    if ($mac) { $results.Add($mac) }
}

if ($results.Count -eq 0) {
    Write-Host "No drive-letter paths to convert (UNC and relative paths are not supported)."
    exit 1
}

$Output = $results -join "`r`n"
$Output | Set-Clipboard
Write-Host "Copied:`n$Output"
