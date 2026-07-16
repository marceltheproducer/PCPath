$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$script:Fails = 0
function Assert-Eq($Actual, $Expected, $Label) {
  if ($Actual -ceq $Expected) { Write-Host "  ok  $Label" }
  else { $script:Fails++; Write-Host "FAIL  $Label`n        expected: $Expected`n        actual:   $Actual" }
}

# Isolated config home.
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("pcpath_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp | Out-Null
$env:USERPROFILE = $tmp
Set-Content -Path (Join-Path $tmp ".pcpath_mappings") -Value "EDIT=E`nCONTENT=K" -Encoding UTF8

# --- Preservation witness: Mac->PC keeps space + filename ---
$in = '\Volumes\EDIT\EastofEden_ESED\Media\GFX\TO GFX\20260610\tim_edt_trl_Beauty_v5_wip04_wm.mp4'
# convert_to_pc_path.ps1 reports via Write-Host (stream 6); redirect 6->1 to capture it.
$out = ((& "$Root\windows\convert_to_pc_path.ps1" $in) 6>&1 | Select-Object -First 1).ToString() -replace '^Copied: ', ''
Assert-Eq $out 'E:\EastofEden_ESED\Media\GFX\TO GFX\20260610\tim_edt_trl_Beauty_v5_wip04_wm.mp4' "windows: Mac->PC space + filename preserved"

. "$Root\windows\pcpath_common.ps1"

# Quote stripping
Assert-Eq (Remove-WrappingQuotes '"E:\foo"') 'E:\foo' "win: strip double quotes"
Assert-Eq (Remove-WrappingQuotes "'/Volumes/EDIT/x'") "/Volumes/EDIT/x" "win: strip single quotes"
Assert-Eq (Remove-WrappingQuotes 'E:\TO GFX\f') 'E:\TO GFX\f' "win: unquoted untouched"

# Suffix stripping
$suf = @('_LA')
Assert-Eq (Remove-SegmentSuffixes 'E:\MONA_Moana_LA\shots' $suf) 'E:\MONA_Moana\shots' "win: strip _LA (win sep)"
Assert-Eq (Remove-SegmentSuffixes '/Volumes/EDIT/MONA_Moana_LA/x' $suf) '/Volumes/EDIT/MONA_Moana/x' "win: strip _LA (mac sep)"
Assert-Eq (Remove-SegmentSuffixes 'E:\TO GFX_LA\x' $suf) 'E:\TO GFX\x' "win: keep space strip suffix"
Assert-Eq (Remove-SegmentSuffixes 'E:\_LA\x' $suf) 'E:\_LA\x' "win: never empties segment"
Assert-Eq (Remove-SegmentSuffixes 'E:\MONA_Moana_LA\x' @()) 'E:\MONA_Moana_LA\x' "win: empty list no-op"

# STRIP= parsing — default
Set-Content -Path (Join-Path $tmp ".pcpath_mappings") -Value "EDIT=E" -Encoding UTF8
Assert-Eq ((Get-PCPathStripSuffixes) -join ',') '_LA' "win: default suffix _LA"
# STRIP= parsing — explicit replaces default
Set-Content -Path (Join-Path $tmp ".pcpath_mappings") -Value "EDIT=E`nSTRIP=_NY" -Encoding UTF8
Assert-Eq ((Get-PCPathStripSuffixes) -join ',') '_NY' "win: STRIP= replaces default"
Set-Content -Path (Join-Path $tmp ".pcpath_mappings") -Value "EDIT=E`nCONTENT=K" -Encoding UTF8

# Mac->PC quoted input + suffix + space
$o = (& "$Root\windows\convert_to_pc_path.ps1" '"/Volumes/EDIT/MONA_Moana_LA/TO GFX/f.mp4"' 6>&1 | Select-Object -First 1).ToString() -replace '^Copied: ', ''
Assert-Eq $o 'E:\MONA_Moana\TO GFX\f.mp4' "win e2e: Mac->PC quote+suffix+space"

# PC->Mac (copy_mac_path) suffix + space
$o2raw = (& "$Root\windows\copy_mac_path.ps1" 'E:\MONA_Moana_LA\TO GFX\f.mp4' 6>&1 | ForEach-Object { $_.ToString() })
$o2 = ($o2raw | Where-Object { $_ -like '*Volumes*' } | Select-Object -First 1) -replace '^Copied:\s*', ''
Assert-Eq $o2.Trim() '/Volumes/EDIT/MONA_Moana/TO GFX/f.mp4' "win e2e: PC->Mac suffix+space"

# --- UNC input (host dropped, share == volume — mirrors smb://) ---
$u1 = (& "$Root\windows\convert_to_pc_path.ps1" '\\calamedia\EDIT\_library\Tech' 6>&1 | Select-Object -First 1).ToString() -replace '^Copied: ', ''
Assert-Eq $u1 'E:\_library\Tech' "win e2e: UNC -> drive letter"
$u2 = (& "$Root\windows\convert_to_pc_path.ps1" '\\calamedia.domain.tld\CONTENT\Projects\video.mp4' 6>&1 | Select-Object -First 1).ToString() -replace '^Copied: ', ''
Assert-Eq $u2 'K:\Projects\video.mp4' "win e2e: UNC FQDN host dropped"
$u3 = (& "$Root\windows\convert_to_pc_path.ps1" '\\srv\EDIT' 6>&1 | Select-Object -First 1).ToString() -replace '^Copied: ', ''
Assert-Eq $u3 'E:\' "win e2e: UNC share only"
$u4 = (& "$Root\windows\convert_to_pc_path.ps1" '\\calamedia\EDIT\MONA_Moana_LA\TO GFX\f.mp4' 6>&1 | Select-Object -First 1).ToString() -replace '^Copied: ', ''
Assert-Eq $u4 'E:\MONA_Moana\TO GFX\f.mp4' "win e2e: UNC suffix + space"
$u5 = (& "$Root\windows\convert_to_pc_path.ps1" '\\?\C:\x' 6>&1 | Select-Object -First 1).ToString() -replace '^Copied: ', ''
Assert-Eq $u5 '\\?\C:\x' "win e2e: device path passthrough"
$u6 = (& "$Root\windows\convert_to_pc_path.ps1" '\\Volumes\EDIT\x' 6>&1 | Select-Object -First 1).ToString() -replace '^Copied: ', ''
Assert-Eq $u6 'E:\x' "win e2e: \\Volumes precedence over UNC"
$u7raw = (& "$Root\windows\copy_mac_path.ps1" '\\calamedia\EDIT\MONA_Moana_LA\f.mp4' 6>&1 | ForEach-Object { $_.ToString() })
$u7 = ($u7raw | Where-Object { $_ -like '*Volumes*' } | Select-Object -First 1) -replace '^Copied:\s*', ''
Assert-Eq $u7.Trim() '/Volumes/EDIT/MONA_Moana/f.mp4' "win e2e: copy_mac_path UNC -> Mac"
$u8 = (& "$Root\windows\convert_to_pc_path.ps1" '\\srv\ZNOPE\x' 6>&1 | Select-Object -First 1).ToString() -replace '^Copied: ', ''
Assert-Eq $u8 '?(ZNOPE):\x' "win e2e: UNC unknown share -> placeholder"

# Auto-discovery with an injected fake volume list.
$fake = @(
  [pscustomobject]@{ DriveLetter = 'E'; FileSystemLabel = 'EDIT' },
  [pscustomobject]@{ DriveLetter = 'F'; FileSystemLabel = 'MONA' },
  [pscustomobject]@{ DriveLetter = 'G'; FileSystemLabel = '' }
)
# Volume name -> letter
Assert-Eq (Resolve-VolumeFallback -Name 'MONA' -Direction 'VolToLetter' -Volumes $fake) 'F' "win: discover letter from label"
Assert-Eq (Resolve-VolumeFallback -Name 'mona' -Direction 'VolToLetter' -Volumes $fake) 'F' "win: label match case-insensitive"
Assert-Eq (Resolve-VolumeFallback -Name 'NOPE' -Direction 'VolToLetter' -Volumes $fake) $null "win: unknown label -> null"
# Letter -> volume name
Assert-Eq (Resolve-VolumeFallback -Name 'E' -Direction 'LetterToVol' -Volumes $fake) 'EDIT' "win: discover label from letter"
Assert-Eq (Resolve-VolumeFallback -Name 'G' -Direction 'LetterToVol' -Volumes $fake) $null "win: unlabeled drive -> null"

Write-Host "`n$script:Fails failure(s)"
if ($script:Fails -gt 0) { exit 1 } else { exit 0 }
