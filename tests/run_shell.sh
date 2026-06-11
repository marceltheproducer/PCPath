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

printf '\n%d failure(s)\n' "$FAILS"
exit $(( FAILS > 0 ? 1 : 0 ))
