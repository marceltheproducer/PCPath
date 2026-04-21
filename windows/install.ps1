# PCPath Installer for Windows
# Adds context menu entries for path conversion.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallDir = "$env:USERPROFILE\.pcpath"
$ConfigFile = "$env:USERPROFILE\.pcpath_mappings"
$LogFile    = "$InstallDir\install.log"
$Step       = 0
$Total      = 4

function Write-Step {
    param([string]$Label)
    $script:Step++
    Write-Host ("  [{0}/{1}] {2,-35}" -f $script:Step, $script:Total, $Label) -NoNewline
}

Write-Host "Installing PCPath..."
Write-Host ""

Write-Step "Creating install directory..."
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Write-Host "done"

Write-Step "Copying scripts..."
Copy-Item "$ScriptDir\pcpath_common.ps1"        "$InstallDir\" -Force
Copy-Item "$ScriptDir\copy_mac_path.ps1"        "$InstallDir\" -Force
Copy-Item "$ScriptDir\convert_to_pc_path.ps1"   "$InstallDir\" -Force
Write-Host "done"

Write-Step "Adding context menu entries..."
$RegPathFile           = "HKCU:\Software\Classes\*\shell\CopyAsMacPath"
$RegPathDir            = "HKCU:\Software\Classes\Directory\shell\CopyAsMacPath"
$RegPathBg             = "HKCU:\Software\Classes\Directory\Background\shell\CopyAsMacPath"
$RegPathConvertBg      = "HKCU:\Software\Classes\Directory\Background\shell\ConvertToPCPath"
$RegPathConvertDesktop = "HKCU:\Software\Classes\DesktopBackground\shell\ConvertToPCPath"
$AllRegPaths = @($RegPathFile, $RegPathDir, $RegPathBg, $RegPathConvertBg, $RegPathConvertDesktop)

$PsCmd        = "powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\copy_mac_path.ps1`""
$ConvertPsCmd = "powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\convert_to_pc_path.ps1`""

try {
    New-Item -Path "$RegPathFile\command" -Force | Out-Null
    Set-ItemProperty -Path $RegPathFile -Name "(Default)" -Value "Copy as Mac Path"
    Set-ItemProperty -Path $RegPathFile -Name "Icon"      -Value "shell32.dll,134"
    Set-ItemProperty -Path "$RegPathFile\command" -Name "(Default)" -Value "$PsCmd `"%1`""

    New-Item -Path "$RegPathDir\command" -Force | Out-Null
    Set-ItemProperty -Path $RegPathDir -Name "(Default)" -Value "Copy as Mac Path"
    Set-ItemProperty -Path $RegPathDir -Name "Icon"      -Value "shell32.dll,134"
    Set-ItemProperty -Path "$RegPathDir\command" -Name "(Default)" -Value "$PsCmd `"%V`""

    New-Item -Path "$RegPathBg\command" -Force | Out-Null
    Set-ItemProperty -Path $RegPathBg -Name "(Default)" -Value "Copy as Mac Path"
    Set-ItemProperty -Path $RegPathBg -Name "Icon"      -Value "shell32.dll,134"
    Set-ItemProperty -Path "$RegPathBg\command" -Name "(Default)" -Value "$PsCmd `"%V`""

    New-Item -Path "$RegPathConvertBg\command" -Force | Out-Null
    Set-ItemProperty -Path $RegPathConvertBg -Name "(Default)" -Value "Convert to PC Path"
    Set-ItemProperty -Path $RegPathConvertBg -Name "Icon"      -Value "shell32.dll,134"
    Set-ItemProperty -Path "$RegPathConvertBg\command" -Name "(Default)" -Value $ConvertPsCmd

    New-Item -Path "$RegPathConvertDesktop\command" -Force | Out-Null
    Set-ItemProperty -Path $RegPathConvertDesktop -Name "(Default)" -Value "Convert to PC Path"
    Set-ItemProperty -Path $RegPathConvertDesktop -Name "Icon"      -Value "shell32.dll,134"
    Set-ItemProperty -Path "$RegPathConvertDesktop\command" -Name "(Default)" -Value $ConvertPsCmd
} catch {
    Write-Host "Error creating registry entries: $_" -ForegroundColor Red
    Write-Host "Rolling back..." -ForegroundColor Yellow
    foreach ($path in $AllRegPaths) {
        if (Test-Path $path) { Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue }
    }
    throw
}
Write-Host "done"

Write-Step "Writing config..."
$DefaultConfig = Join-Path (Split-Path -Parent $ScriptDir) "pcpath_mappings.default"
if (-not (Test-Path $ConfigFile)) {
    Copy-Item $DefaultConfig $ConfigFile
    Write-Host "done"
} else {
    Write-Host "done (already existed, kept)"
}

Write-Host ""

# Self-test
Write-Host "Running self-test..."
. "$InstallDir\pcpath_common.ps1"
$DriveToVol = Get-PCPathMappings -DriveToVolume
if ($DriveToVol.Count -eq 0) {
    Write-Host "  Warning: no mappings found -- skipping conversion test"
} else {
    $VolToLetter = Get-PCPathMappings
    $TestLetter  = @($DriveToVol.Keys)[0]
    $TestVol     = $DriveToVol[$TestLetter]
    $TestInput   = "${TestLetter}:\Projects\test.mp4"
    $MacPath     = "/Volumes/$TestVol/Projects/test.mp4"
    Write-Host "  Input:   $TestInput"
    Write-Host "  Output:  $MacPath"
    if ($MacPath -like "/Volumes/*" -and $VolToLetter[$TestVol] -eq $TestLetter) {
        Write-Host "OK  Conversion working"
    } else {
        Write-Host "FAIL  Conversion failed -- check $ConfigFile" -ForegroundColor Red
        exit 1
    }
}

# Record install
try {
    Add-Content -Path $LogFile -Value "$(([datetime]::UtcNow).ToString('yyyy-MM-ddTHH:mm:ss')) PCPath installed via manual installer" -Encoding UTF8
} catch {
    Write-Host "  (Could not write install log: $_)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "OK  PCPath installed successfully"
Write-Host ""
Write-Host "Context menu actions:"
Write-Host "  Copy as Mac Path     Right-click any file or folder"
Write-Host "  Convert to PC Path   Right-click empty space in a folder or desktop"
Write-Host ""
Write-Host "Drive mappings: $ConfigFile"
Write-Host "Edit that file to add or change volume-to-drive-letter mappings."
