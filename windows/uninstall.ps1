# PCPath Uninstaller for Windows
# Removes context menu entries and installed scripts.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$InstallDir = "$env:USERPROFILE\.pcpath"
$ConfigFile = "$env:USERPROFILE\.pcpath_mappings"

Write-Host "Uninstalling PCPath..."

# Remove context menu entries
$RegPaths = @(
    "HKCU:\Software\Classes\*\shell\CopyAsMacPath",
    "HKCU:\Software\Classes\Directory\shell\CopyAsMacPath",
    "HKCU:\Software\Classes\Directory\Background\shell\CopyAsMacPath"
)

foreach ($path in $RegPaths) {
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force
    }
}

# Remove installed scripts (validate path ends with \.pcpath before deleting)
if ((Test-Path $InstallDir) -and ($InstallDir -match '\\\.pcpath$')) {
    Remove-Item -Path $InstallDir -Recurse -Force
}

Write-Host ""
Write-Host "PCPath has been uninstalled."
Write-Host "Config file kept at $ConfigFile (delete manually if not needed)."
