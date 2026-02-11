# PCPath Remote Installer for Windows
# Usage: irm https://raw.githubusercontent.com/marceltheproducer/PCPath/master/windows/remote_install.ps1 | iex

$ErrorActionPreference = "Stop"

$RepoUrl = "https://github.com/marceltheproducer/PCPath/archive/refs/heads/master.zip"
$TmpDir = Join-Path $env:TEMP "pcpath_install_$(Get-Random)"
$ZipFile = Join-Path $TmpDir "pcpath.zip"

try {
    New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null

    Write-Host "Downloading PCPath..."
    Invoke-WebRequest -Uri $RepoUrl -OutFile $ZipFile -UseBasicParsing

    Write-Host "Extracting..."
    Expand-Archive -Path $ZipFile -DestinationPath $TmpDir -Force

    # The archive extracts to PCPath-master/
    $ExtractedDir = Join-Path $TmpDir "PCPath-master\windows"

    Write-Host ""
    & "$ExtractedDir\install.ps1"
}
finally {
    if (Test-Path $TmpDir) {
        Remove-Item -Path $TmpDir -Recurse -Force
    }
}
