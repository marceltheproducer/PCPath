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
