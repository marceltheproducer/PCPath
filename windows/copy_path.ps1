# PCPath for Windows - Copy as Path
# Copies the full Windows path of every selected Explorer item, one per
# line (CRLF), to the clipboard. Functionally the same as Explorer's
# built-in "Copy as path" but always emits each path on its own line —
# no surrounding quotes, no single-line concatenation.

param(
    [Parameter(Position=0)]
    [string]$ClickedPath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-ExplorerSelectionPaths {
    param([string]$ClickedPath)
    try {
        $shell = New-Object -ComObject Shell.Application
        $clickedFull = if ($ClickedPath) { [IO.Path]::GetFullPath($ClickedPath) } else { $null }

        $candidate = $null
        foreach ($w in $shell.Windows()) {
            try {
                $doc = $w.Document
                if (-not $doc) { continue }
                $sel = $doc.SelectedItems()
                if (-not $sel -or $sel.Count -eq 0) { continue }

                $paths = @($sel | ForEach-Object { $_.Path })
                if ($clickedFull) {
                    foreach ($p in $paths) {
                        if ($p -and ([IO.Path]::GetFullPath($p) -ieq $clickedFull)) {
                            return ,$paths
                        }
                    }
                }
                if (-not $candidate) { $candidate = $paths }
            } catch { continue }
        }
        if ($candidate) { return ,$candidate }
    } catch { }

    if ($ClickedPath) { return ,@($ClickedPath) }
    return @()
}

$paths = Get-ExplorerSelectionPaths -ClickedPath $ClickedPath
if (-not $paths -or $paths.Count -eq 0) { exit 0 }

($paths -join "`r`n") | Set-Clipboard
