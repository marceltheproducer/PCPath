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

Write-Host "`n$script:Fails failure(s)"
if ($script:Fails -gt 0) { exit 1 } else { exit 0 }
