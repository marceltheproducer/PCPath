#!/bin/bash
# PCPath shell tests. Runs on any bash (Git Bash on Windows ok).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILS=0
eq() { # eq <actual> <expected> <label>
  if [[ "$1" == "$2" ]]; then printf '  ok  %s\n' "$3"
  else FAILS=$((FAILS+1)); printf 'FAIL  %s\n        expected: %s\n        actual:   %s\n' "$3" "$2" "$1"; fi
}

# pbcopy/osascript shim so copy_pc_path.sh output is capturable.
SHIM="$(mktemp -d)"
printf '#!/bin/bash\ncat > "%s/clip.txt"\n' "$SHIM" > "$SHIM/pbcopy"
printf '#!/bin/bash\nexit 0\n' > "$SHIM/osascript"
chmod +x "$SHIM/pbcopy" "$SHIM/osascript"
export PATH="$SHIM:$PATH"
clip() { cat "$SHIM/clip.txt"; }

# Isolated config home so the developer's ~/.pcpath_mappings doesn't leak in.
export HOME="$SHIM"
printf 'EDIT=E\nCONTENT=K\n' > "$SHIM/.pcpath_mappings"

# --- Preservation witness: PC->Mac keeps space + filename ---
out="$(bash "$ROOT/paste_mac_path.sh" '\Volumes\EDIT\EastofEden_ESED\Media\GFX\TO GFX\20260610\tim_edt_trl_Beauty_v5_wip04_wm.mp4' 2>/dev/null)"
eq "$out" "/Volumes/EDIT/EastofEden_ESED/Media/GFX/TO GFX/20260610/tim_edt_trl_Beauty_v5_wip04_wm.mp4" "shell: PC->Mac space + filename preserved"

# --- Preservation witness: Mac->PC keeps space + filename ---
bash "$ROOT/copy_pc_path.sh" "/Volumes/EDIT/EastofEden_ESED/Media/GFX/TO GFX/20260610/tim_edt_trl_Beauty_v5_wip04_wm.mp4" >/dev/null 2>&1
eq "$(clip)" 'E:\EastofEden_ESED\Media\GFX\TO GFX\20260610\tim_edt_trl_Beauty_v5_wip04_wm.mp4' "shell: Mac->PC space + filename preserved"

# --- Common helpers (sourced) ---
source "$ROOT/pcpath_common.sh"

# Quote stripping
eq "$(strip_wrapping_quotes '"E:\foo"')" 'E:\foo' "shell: strip double quotes"
eq "$(strip_wrapping_quotes "'/Volumes/EDIT/x'")" "/Volumes/EDIT/x" "shell: strip single quotes"
eq "$(strip_wrapping_quotes '/Volumes/EDIT/TO GFX/f')" '/Volumes/EDIT/TO GFX/f' "shell: unquoted untouched"
eq "$(strip_wrapping_quotes '"mismatch'"'"'')" '"mismatch'"'"'' "shell: mismatched untouched"

# Suffix stripping (default _LA from no STRIP= in config)
pcpath_load_mappings
eq "$(strip_segment_suffixes 'E:/MONA_Moana_LA/shots/010')" 'E:/MONA_Moana/shots/010' "shell: strip _LA default"
eq "$(strip_segment_suffixes '/Volumes/EDIT/TO GFX_LA/x')" '/Volumes/EDIT/TO GFX/x' "shell: keep space strip suffix"
eq "$(strip_segment_suffixes '/Volumes/EDIT/TO GFX/x')" '/Volumes/EDIT/TO GFX/x' "shell: no tag unchanged"
eq "$(strip_segment_suffixes '/Volumes/EDIT/_LA/x')" '/Volumes/EDIT/_LA/x' "shell: never empties segment"

# Explicit STRIP= replaces default
printf 'EDIT=E\nSTRIP=_NY\n' > "$SHIM/.pcpath_mappings"
pcpath_load_mappings
eq "$(strip_segment_suffixes '/Volumes/EDIT/Proj_NY/Proj_LA')" '/Volumes/EDIT/Proj/Proj_LA' "shell: STRIP= replaces default (_NY only)"
printf 'EDIT=E\nCONTENT=K\n' > "$SHIM/.pcpath_mappings"
pcpath_load_mappings

# --- End-to-end wiring ---
# PC->Mac: quoted input + suffix + space, using an UNmapped letter (Z) so the
# placeholder path is exercised (EDIT=E in config means E is already mapped).
out="$(bash "$ROOT/paste_mac_path.sh" '"Z:\MONA_Moana_LA\TO GFX\f.mp4"' 2>/dev/null)"
eq "$out" "/Volumes/?(Z)/MONA_Moana/TO GFX/f.mp4" "shell e2e: PC->Mac quote+suffix (unmapped Z)"

# PC->Mac with mapped drive (EDIT=E)
out="$(bash "$ROOT/paste_mac_path.sh" 'E:\MONA_Moana_LA\shots' 2>/dev/null)"
eq "$out" "/Volumes/EDIT/MONA_Moana/shots" "shell e2e: PC->Mac suffix on mapped drive"

# \Volumes\ form keeps space, strips suffix
out="$(bash "$ROOT/paste_mac_path.sh" '\Volumes\EDIT\MONA_Moana_LA\TO GFX\f.mp4' 2>/dev/null)"
eq "$out" "/Volumes/EDIT/MONA_Moana/TO GFX/f.mp4" "shell e2e: \\Volumes\\ suffix + space"

# --- UNC input (host dropped, share == volume — mirrors smb://) ---
out="$(bash "$ROOT/paste_mac_path.sh" '\\calamedia\EDIT\MONA_Moana_LA\TO GFX\f.mp4' 2>/dev/null)"
eq "$out" "/Volumes/EDIT/MONA_Moana/TO GFX/f.mp4" "shell e2e: UNC suffix + space"
out="$(bash "$ROOT/paste_mac_path.sh" '\\calamedia.domain.tld\CONTENT\x\y' 2>/dev/null)"
eq "$out" "/Volumes/CONTENT/x/y" "shell e2e: UNC FQDN host dropped"
out="$(bash "$ROOT/paste_mac_path.sh" '\\srv\EDIT' 2>/dev/null)"
eq "$out" "/Volumes/EDIT" "shell e2e: UNC share only"
out="$(bash "$ROOT/paste_mac_path.sh" '\\?\C:\x' 2>/dev/null)"
eq "$out" '\\?\C:\x' "shell e2e: device path passthrough"
out="$(bash "$ROOT/paste_mac_path.sh" '\\srv' 2>/dev/null)"
eq "$out" '\\srv' "shell e2e: bare server passthrough"
out="$(bash "$ROOT/paste_mac_path.sh" '\\Volumes\EDIT\x' 2>/dev/null)"
eq "$out" "/Volumes/EDIT/x" "shell e2e: \\Volumes precedence over UNC"
out="$(bash "$ROOT/paste_mac_path.sh" '\\srv\GFX\a/b\c' 2>/dev/null)"
eq "$out" "/Volumes/GFX/a/b/c" "shell e2e: UNC mixed separators"

# Mac->PC: suffix strip, space kept
bash "$ROOT/copy_pc_path.sh" "/Volumes/EDIT/MONA_Moana_LA/TO GFX/f.mp4" >/dev/null 2>&1
eq "$(clip)" 'E:\MONA_Moana\TO GFX\f.mp4' "shell e2e: Mac->PC suffix + space"

printf '\n%d failure(s)\n' "$FAILS"
exit $(( FAILS > 0 ? 1 : 0 ))
