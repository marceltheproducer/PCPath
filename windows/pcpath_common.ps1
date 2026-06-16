# PCPath shared configuration loader for Windows
# Sourced by copy_mac_path.ps1 and convert_to_pc_path.ps1

function Get-PCPathMappings {
    param(
        [switch]$DriveToVolume  # If set, returns drive->volume; otherwise volume->drive
    )

    $ConfigFile = "$env:USERPROFILE\.pcpath_mappings"
    $DefaultMappings = @"
CONTENT=K
GFX=G
EDIT=E
THE_NETWORK=N
DEV=V
"@

    $Source = $DefaultMappings
    if (Test-Path $ConfigFile) {
        $Source = Get-Content $ConfigFile -Raw -Encoding UTF8
    }

    $Map = [System.Collections.Hashtable]::new([System.StringComparer]::OrdinalIgnoreCase)

    $Source -split "`n" | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            $parts = $line -split '=', 2
            if ($parts.Count -eq 2) {
                $volName = $parts[0].Trim()
                $driveLetter = $parts[1].Trim().ToUpper()
                if ($driveLetter -match '^[A-Z]$') {
                    if ($DriveToVolume) {
                        $Map[$driveLetter] = $volName
                    } else {
                        $Map[$volName] = $driveLetter
                    }
                }
            }
        }
    }

    return $Map
}

function Get-PCPathStripSuffixes {
    $ConfigFile = "$env:USERPROFILE\.pcpath_mappings"
    $suffixes = New-Object System.Collections.Generic.List[string]
    $configured = $false
    if (Test-Path $ConfigFile) {
        foreach ($raw in (Get-Content $ConfigFile -Encoding UTF8)) {
            $line = $raw.Trim()
            if (-not $line -or $line.StartsWith('#')) { continue }
            if ($line -match '^[Ss][Tt][Rr][Ii][Pp]\s*=(.*)$') {
                $configured = $true
                $val = $Matches[1].Trim()
                if ($val) { $suffixes.Add($val) }
            }
        }
    }
    # $configured stays true even if all STRIP= values are empty -> returns @(), disabling stripping
    if (-not $configured) { return ,@('_LA') }
    return ,$suffixes.ToArray()
}

function Remove-WrappingQuotes {
    param([string]$s)
    if ($s.Length -ge 2) {
        $f = $s[0]; $l = $s[$s.Length - 1]
        if (($f -eq '"' -and $l -eq '"') -or ($f -eq "'" -and $l -eq "'")) {
            return $s.Substring(1, $s.Length - 2)
        }
    }
    return $s
}

function Remove-SegmentSuffixes {
    param([string]$Path, [string[]]$Suffixes)
    if (-not $Suffixes -or $Suffixes.Count -eq 0) { return $Path }
    return [regex]::Replace($Path, '[^\\/]+', {
        param($m)
        $seg = $m.Value
        foreach ($suf in $Suffixes) {
            if ($suf -and $seg.Length -gt $suf.Length -and $seg.EndsWith($suf, [System.StringComparison]::Ordinal)) {
                return $seg.Substring(0, $seg.Length - $suf.Length)
            }
        }
        return $seg
    })
}

function Get-LiveVolumeMap {
    try { return @(Get-Volume | Where-Object { $_.DriveLetter -and $_.FileSystemLabel }) }
    catch { return @() }
}

function Resolve-VolumeFallback {
    param(
        [string]$Name,
        [ValidateSet('VolToLetter', 'LetterToVol')] [string]$Direction,
        [array]$Volumes
    )
    if ($null -eq $Volumes) { $Volumes = Get-LiveVolumeMap }
    foreach ($v in $Volumes) {
        if (-not $v.DriveLetter -or -not $v.FileSystemLabel) { continue }
        if ($Direction -eq 'VolToLetter') {
            if ($v.FileSystemLabel -ieq $Name) { return ([string]$v.DriveLetter).ToUpper() }
        } else {
            if (([string]$v.DriveLetter).ToUpper() -eq $Name.ToUpper()) { return [string]$v.FileSystemLabel }
        }
    }
    return $null
}
