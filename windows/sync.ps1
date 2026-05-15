# PCPath sync-and-release pipeline.
#
# 1. Bumps the minor segment of PCPATH_VERSION in PCPathInstall.nsi  (2.0 -> 2.1)
# 2. Rebuilds PCPathInstall.exe (build timestamp auto-stamps too)
# 3. Syncs the windows/ folder to all 3 secondary locations:
#      - V:\General Dev\Design\_Out\PCPath\windows\
#      - c:\Users\marcel.perez\work\PCPath\PCPath\windows\
#      - G:\_library\Tech\DevOps\PCPath\        (flat layout)
# 4. Commits the rebuilt exe + bumped nsi in both git repos
# 5. Pushes the GitHub clone
#
# Use -NoBump to ship the current version without incrementing (e.g. retrying
# a failed sync). Use -BumpMajor to roll from 2.x to 3.0 instead.

[CmdletBinding()]
param(
    [switch]$NoBump,
    [switch]$BumpMajor,
    [string]$CommitMessage
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$Nsi       = Join-Path $ScriptDir "PCPathInstall.nsi"
$Exe       = Join-Path $ScriptDir "PCPathInstall.exe"
$RepoRoot  = Split-Path -Parent $ScriptDir

$MakeNsis = @(
    "$env:ProgramFiles\NSIS\makensis.exe",
    "${env:ProgramFiles(x86)}\NSIS\makensis.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $MakeNsis) { throw "makensis.exe not found. Install NSIS first." }

# --- 1. Bump version in the NSI -----------------------------------------------
# Read/write with explicit UTF-8 so non-ASCII characters (em-dashes etc.)
# survive a round-trip. Without -Encoding UTF8, PS 5.1 reads with the system
# codepage and corrupts the bytes on save.
$nsiText = Get-Content $Nsi -Raw -Encoding UTF8
if ($nsiText -notmatch '(?m)^!define\s+PCPATH_VERSION\s+"(\d+)\.(\d+)"') {
    throw "Could not find PCPATH_VERSION line in $Nsi"
}
$major = [int]$Matches[1]
$minor = [int]$Matches[2]
$oldVersion = "$major.$minor"

if ($NoBump) {
    $newVersion = $oldVersion
} elseif ($BumpMajor) {
    $newVersion = ("{0}.0" -f ($major + 1))
} else {
    $newVersion = ("{0}.{1}" -f $major, ($minor + 1))
}

if ($newVersion -ne $oldVersion) {
    $nsiText = $nsiText -replace '(?m)^(!define\s+PCPATH_VERSION\s+)"\d+\.\d+"', "`$1`"$newVersion`""
    Set-Content -Path $Nsi -Value $nsiText -Encoding UTF8 -NoNewline
    Write-Host "Version: $oldVersion -> $newVersion" -ForegroundColor Cyan
} else {
    Write-Host "Version: $oldVersion (no bump)" -ForegroundColor Yellow
}

# --- 2. Build -----------------------------------------------------------------
Write-Host "Building installer..." -ForegroundColor Cyan
& $MakeNsis $Nsi | Select-Object -Last 2 | Write-Host
if ($LASTEXITCODE -ne 0) { throw "makensis failed (exit $LASTEXITCODE)" }
$build = (Get-Item $Exe).VersionInfo.ProductVersion
Write-Host "Built: $build" -ForegroundColor Green

# --- 3. Sync to all secondary locations ---------------------------------------
$WinDests = @(
    "V:\General Dev\Design\_Out\PCPath\windows",
    "C:\Users\marcel.perez\work\PCPath\PCPath\windows"
)
$FlatDest = "G:\_library\Tech\DevOps\PCPath"

$WinFiles = Get-ChildItem $ScriptDir -File | Where-Object {
    $_.Name -notin @("install.log") -and -not $_.Name.StartsWith(".")
}

Write-Host "Syncing windows/ -> $($WinDests.Count) repo-style locations + flat G: ..." -ForegroundColor Cyan
foreach ($d in $WinDests) {
    if (-not (Test-Path $d)) { Write-Host "  skip (missing): $d" -ForegroundColor Yellow; continue }
    foreach ($f in $WinFiles) { Copy-Item $f.FullName (Join-Path $d $f.Name) -Force }
    Write-Host "  ok: $d"
}
if (Test-Path $FlatDest) {
    foreach ($f in $WinFiles) { Copy-Item $f.FullName (Join-Path $FlatDest $f.Name) -Force }
    Write-Host "  ok: $FlatDest"
} else {
    Write-Host "  skip (missing): $FlatDest" -ForegroundColor Yellow
}

# --- 4 + 5. Commit & push -----------------------------------------------------
$msg = if ($CommitMessage) {
    "release: PCPath $newVersion`n`n$CommitMessage"
} else {
    "release: PCPath $newVersion (build $build)"
}

$GitRepos = @(
    @{ Path = $RepoRoot;                                                Push = $false },
    @{ Path = "C:\Users\marcel.perez\work\PCPath\PCPath";               Push = $true  }
)

foreach ($r in $GitRepos) {
    if (-not (Test-Path (Join-Path $r.Path ".git"))) {
        Write-Host "  skip git (not a repo): $($r.Path)" -ForegroundColor Yellow
        continue
    }
    Write-Host "Committing in $($r.Path)..." -ForegroundColor Cyan
    # Do NOT redirect 2>&1 on git: in PS 5.1, that wraps stderr lines (like
    # the "LF will be replaced by CRLF" warning) as NativeCommandError records
    # which become terminating errors under $ErrorActionPreference = "Stop".
    & git -C $r.Path add windows/PCPathInstall.nsi windows/PCPathInstall.exe windows/*.ps1 windows/*.vbs | Out-Null
    $status = & git -C $r.Path status --porcelain
    if (-not $status) {
        Write-Host "  nothing to commit"
        continue
    }
    & git -C $r.Path commit -m $msg | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git commit failed in $($r.Path)" }
    $sha = & git -C $r.Path rev-parse --short HEAD
    Write-Host "  $sha" -ForegroundColor Green

    if ($r.Push) {
        Write-Host "  pushing to origin..." -ForegroundColor Cyan
        & git -C $r.Path push origin main
        if ($LASTEXITCODE -ne 0) { throw "git push failed" }
    }
}

Write-Host ""
Write-Host "Released PCPath $newVersion (build $build)" -ForegroundColor Green
