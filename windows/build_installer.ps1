# Rebuild PCPathInstall.exe from source.
# Run this whenever pcpath_common.ps1, copy_mac_path.ps1,
# convert_to_pc_path.ps1, or pcpath_mappings.default change.
#
# Requires NSIS: https://nsis.sourceforge.io/

$RepoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $RepoRoot
try {
    makensis "windows\PCPathInstall.nsi"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Built: windows\PCPathInstall.exe" -ForegroundColor Green
    } else {
        Write-Host "Build failed (exit $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}
