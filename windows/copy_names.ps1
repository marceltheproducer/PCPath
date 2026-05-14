# PCPath for Windows - Copy names of selected Explorer items to clipboard
# Joins each name with a single CRLF so paste output is clean.
#
# Invoked from the Explorer context menu with the right-clicked file as %1.
# We don't use %1 directly — instead we query Explorer for the full current
# selection so that multi-select works regardless of how many items are picked.

param(
    [Parameter(Position=0)]
    [string]$ClickedPath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-ExplorerSelectionNames {
    param([string]$ClickedPath)

    $shell = New-Object -ComObject Shell.Application
    try {
        # Find the Explorer window whose current selection includes the clicked
        # item. Falls back to the topmost window if we can't match.
        $clickedFull = if ($ClickedPath) { [IO.Path]::GetFullPath($ClickedPath) } else { $null }

        $candidate = $null
        foreach ($w in $shell.Windows()) {
            try {
                $doc = $w.Document
                if (-not $doc) { continue }
                $sel = $doc.SelectedItems()
                if (-not $sel -or $sel.Count -eq 0) { continue }

                if ($clickedFull) {
                    foreach ($it in $sel) {
                        if ($it.Path -and ([IO.Path]::GetFullPath($it.Path) -ieq $clickedFull)) {
                            return ,@($sel | ForEach-Object { $_.Name })
                        }
                    }
                }
                if (-not $candidate) { $candidate = $sel }
            } catch { continue }
        }

        if ($candidate) {
            return ,@($candidate | ForEach-Object { $_.Name })
        }
    } catch { }

    # Fallback: just use the single clicked path
    if ($ClickedPath) {
        return ,@([IO.Path]::GetFileName($ClickedPath))
    }
    return @()
}

$names = Get-ExplorerSelectionNames -ClickedPath $ClickedPath

if (-not $names -or $names.Count -eq 0) {
    exit 0
}

$output = ($names -join "`r`n")
$output | Set-Clipboard
