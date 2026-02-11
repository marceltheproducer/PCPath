# PCPath Installer for Windows
# Adds "Copy as Mac Path" to the right-click context menu.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallDir = "$env:USERPROFILE\.pcpath"
$ConfigFile = "$env:USERPROFILE\.pcpath_mappings"

Write-Host "Installing PCPath..."
Write-Host ""

# Create install directory
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# Copy scripts
Copy-Item "$ScriptDir\copy_mac_path.ps1" "$InstallDir\" -Force
Copy-Item "$ScriptDir\convert_to_pc_path.ps1" "$InstallDir\" -Force

# Create default config if it doesn't exist
$DefaultConfig = Join-Path $ScriptDir "..\pcpath_mappings.default"
if (-not (Test-Path $ConfigFile)) {
    Copy-Item $DefaultConfig $ConfigFile
    Write-Host "  Created config file at $ConfigFile"
} else {
    Write-Host "  Config file already exists at $ConfigFile (keeping existing)"
}

# Add "Copy as Mac Path" to file context menu
$RegPathFile = "HKCU:\Software\Classes\*\shell\CopyAsMacPath"
$RegPathDir = "HKCU:\Software\Classes\Directory\shell\CopyAsMacPath"
$RegPathBg = "HKCU:\Software\Classes\Directory\Background\shell\CopyAsMacPath"

$PsCmd = "powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\copy_mac_path.ps1`""

# Files
New-Item -Path "$RegPathFile\command" -Force | Out-Null
Set-ItemProperty -Path $RegPathFile -Name "(Default)" -Value "Copy as Mac Path"
Set-ItemProperty -Path $RegPathFile -Name "Icon" -Value "shell32.dll,134"
Set-ItemProperty -Path "$RegPathFile\command" -Name "(Default)" -Value "$PsCmd `"%1`""

# Folders
New-Item -Path "$RegPathDir\command" -Force | Out-Null
Set-ItemProperty -Path $RegPathDir -Name "(Default)" -Value "Copy as Mac Path"
Set-ItemProperty -Path $RegPathDir -Name "Icon" -Value "shell32.dll,134"
Set-ItemProperty -Path "$RegPathDir\command" -Name "(Default)" -Value "$PsCmd `"%V`""

# Folder backgrounds (right-click empty space inside a folder)
New-Item -Path "$RegPathBg\command" -Force | Out-Null
Set-ItemProperty -Path $RegPathBg -Name "(Default)" -Value "Copy as Mac Path"
Set-ItemProperty -Path $RegPathBg -Name "Icon" -Value "shell32.dll,134"
Set-ItemProperty -Path "$RegPathBg\command" -Name "(Default)" -Value "$PsCmd `"%V`""

Write-Host "  Installed scripts to $InstallDir"
Write-Host "  Added context menu entries"
Write-Host ""
Write-Host "PCPath installed successfully!"
Write-Host ""
Write-Host "Right-click any file or folder to see 'Copy as Mac Path'"
Write-Host ""
Write-Host "Bonus utility:"
Write-Host "  .\convert_to_pc_path.ps1  Converts a Mac path on your clipboard to a PC path"
Write-Host ""
Write-Host "Drive mappings: $ConfigFile"
Write-Host "Edit that file to add or change volume-to-drive-letter mappings."
