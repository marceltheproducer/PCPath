# Rebuild PCPathInstall.exe from source.
# Run this whenever pcpath_common.ps1, copy_mac_path.ps1,
# convert_to_pc_path.ps1, or pcpath_mappings.default change.
#
# Requires NSIS: https://nsis.sourceforge.io/

makensis "$PSScriptRoot\PCPathInstall.nsi"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Built: $PSScriptRoot\PCPathInstall.exe" -ForegroundColor Green
} else {
    Write-Host "Build failed (exit $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}
