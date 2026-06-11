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

Write-Host "`n$script:Fails failure(s)"
if ($script:Fails -gt 0) { exit 1 } else { exit 0 }
