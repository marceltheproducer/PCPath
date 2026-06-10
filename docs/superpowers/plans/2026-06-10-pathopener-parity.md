# Path Opener Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring three Path Opener behaviors to PCPath — wrapping-quote stripping, configurable folder-suffix stripping (`_LA`), and Windows-only drive-label auto-discovery — without ever mutating folder-name bodies or dropping path segments.

**Architecture:** Shared pure helpers live in the per-platform "common" file (`pcpath_common.sh`, `windows/pcpath_common.ps1`) and inline in the web HTML. Each converter calls them at well-defined points: quote-strip on free-text ingest, suffix-strip after volume↔letter conversion, auto-discovery as a fallback when the static map misses. A `tests/` harness exercises each platform directly (bash via stdout + a `pbcopy` shim, PowerShell via dot-sourcing + an injectable volume list, web via Node function-extraction).

**Tech Stack:** Bash, PowerShell 5.1, vanilla browser JS, Node (test runner only).

---

## File Structure

| File | Responsibility |
|---|---|
| `pcpath_common.sh` | Mac: parse `STRIP=`, expose `strip_suffixes[]`, host `strip_wrapping_quotes` + `strip_segment_suffixes` |
| `paste_mac_path.sh` | Mac PC→Mac: call quote-strip on ingest, suffix-strip on output |
| `copy_pc_path.sh` | Mac Mac→PC: call suffix-strip on output |
| `windows/pcpath_common.ps1` | Win: `Get-PCPathStripSuffixes`, `Remove-WrappingQuotes`, `Remove-SegmentSuffixes`, `Get-LiveVolumeMap`, `Resolve-VolumeFallback` |
| `windows/convert_to_pc_path.ps1` | Win Mac→PC: quote-strip ingest, suffix-strip output, volume→letter fallback |
| `windows/copy_mac_path.ps1` | Win PC→Mac: suffix-strip output, letter→volume fallback |
| `web/PCPath_v1.3.0.html` | Web: `stripWrappingQuotes`, `stripSegmentSuffixes`, suffix storage + panel input, wired into `convert()` |
| `tests/run_shell.sh` | Bash assertions |
| `tests/run_windows.ps1` | PowerShell assertions |
| `tests/run_web.mjs` | Node assertions (extracts HTML functions) |
| `verify.sh` | Extended self-test pointer to `tests/run_shell.sh` |

**Shared semantics (all platforms must match):**
- **Quote strip:** if a line's first and last char are the *same* quote (`"` or `'`), remove exactly that one outer pair. Else unchanged.
- **Suffix strip:** for each path segment (split on `/` and/or `\`, separators preserved), if it ends with a configured suffix (exact, case-sensitive) **and** the segment is longer than the suffix, remove the suffix. First matching suffix wins per segment; only one removal per segment.
- **Suffix config:** default list is `["_LA"]`. If config supplies any explicit suffix entries, those **replace** the default.

---

## Task 1: Test harness + preservation characterization (all platforms)

Establishes the runners and locks in the current correct behavior (these pass immediately — they are characterization tests guarding the invariant).

**Files:**
- Create: `tests/run_web.mjs`, `tests/run_shell.sh`, `tests/run_windows.ps1`

- [ ] **Step 1: Create the web runner with the preservation witness**

Create `tests/run_web.mjs`:

```js
import fs from "node:fs";
import path from "node:path";

const html = fs.readFileSync(path.join(import.meta.dirname, "..", "web", "PCPath_v1.3.0.html"), "utf8");

// Extract a named function's full source by brace-matching.
function grab(name) {
  const i = html.indexOf("function " + name);
  if (i < 0) throw new Error("not found: " + name);
  let depth = 0;
  for (let k = html.indexOf("{", i); k < html.length; k++) {
    if (html[k] === "{") depth++;
    else if (html[k] === "}" && --depth === 0) return html.slice(i, k + 1);
  }
  throw new Error("unbalanced: " + name);
}

// Test context: minimal globals the functions reference.
const ctx = { mappings: [{ vol: "EDIT", letter: "E" }], stripSuffixes: [] };
function load(...names) {
  const src = names.map(grab).join("\n");
  // eslint-disable-next-line no-new-func
  return new Function(...Object.keys(ctx), src + "\nreturn {normalizeMacLike,detectType,macToPC,pcToMac" +
    (src.includes("function stripWrappingQuotes") ? ",stripWrappingQuotes" : "") +
    (src.includes("function stripSegmentSuffixes") ? ",stripSegmentSuffixes" : "") +
    "};")(...Object.values(ctx));
}

let failures = 0;
function eq(actual, expected, label) {
  if (actual === expected) { console.log(`  ok  ${label}`); }
  else { failures++; console.log(`FAIL  ${label}\n        expected: ${expected}\n        actual:   ${actual}`); }
}

// --- Preservation witness (current behavior) ---
{
  const fns = load("normalizeMacLike", "detectType", "macToPC", "pcToMac");
  const bs = String.fromCharCode(92);
  const input = "/Volumes/EDIT/EastofEden_ESED/Media/GFX/TO GFX/20260610/tim_edt_trl_Beauty_v5_wip04_wm.mp4".replace(/[/]/g, bs);
  const line = fns.normalizeMacLike(input.trim());
  eq(fns.macToPC(line), "E:" + bs + "EastofEden_ESED" + bs + "Media" + bs + "GFX" + bs + "TO GFX" + bs + "20260610" + bs + "tim_edt_trl_Beauty_v5_wip04_wm.mp4", "web: space + filename preserved");
}

export { html, grab, load, eq };
globalThis.__pcpathFailures = (globalThis.__pcpathFailures ?? 0) + failures;
process.on("exit", () => process.exit(globalThis.__pcpathFailures ? 1 : 0));
```

- [ ] **Step 2: Run the web runner — expect PASS**

Run: `node tests/run_web.mjs`
Expected: `ok  web: space + filename preserved`, exit 0.

- [ ] **Step 3: Create the shell runner with a `pbcopy` shim + preservation witness**

Create `tests/run_shell.sh`:

```bash
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
```

- [ ] **Step 4: Run the shell runner — expect PASS**

Run: `bash tests/run_shell.sh`
Expected: both `ok` lines, `0 failure(s)`, exit 0.

- [ ] **Step 5: Create the Windows runner with preservation witness**

Create `tests/run_windows.ps1`:

```powershell
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
$out = (& "$Root\windows\convert_to_pc_path.ps1" $in | Select-Object -First 1) -replace '^Copied: ', ''
Assert-Eq $out 'E:\EastofEden_ESED\Media\GFX\TO GFX\20260610\tim_edt_trl_Beauty_v5_wip04_wm.mp4' "windows: Mac->PC space + filename preserved"

Write-Host "`n$script:Fails failure(s)"
if ($script:Fails -gt 0) { exit 1 } else { exit 0 }
```

- [ ] **Step 6: Run the Windows runner — expect PASS**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_windows.ps1`
Expected: `ok  windows: Mac->PC space + filename preserved`, `0 failure(s)`, exit 0.

- [ ] **Step 7: Commit**

```bash
git add tests/run_web.mjs tests/run_shell.sh tests/run_windows.ps1
git commit -m "test: add cross-platform harness + folder-name preservation witness"
```

---

## Task 2: Web — wrapping-quote stripping

**Files:**
- Modify: `web/PCPath_v1.3.0.html` (add `stripWrappingQuotes`, wire into `convert()` ~L638)
- Test: `tests/run_web.mjs`

- [ ] **Step 1: Add failing test**

Append to `tests/run_web.mjs` before the `export` line:

```js
// --- Quote stripping ---
{
  const fns = load("stripWrappingQuotes");
  eq(fns.stripWrappingQuotes('"E:\\Project\\comp.aep"'), 'E:\\Project\\comp.aep', "web: strips double quotes");
  eq(fns.stripWrappingQuotes("'/Volumes/EDIT/x'"), "/Volumes/EDIT/x", "web: strips single quotes");
  eq(fns.stripWrappingQuotes('/Volumes/EDIT/TO GFX/f'), '/Volumes/EDIT/TO GFX/f', "web: leaves unquoted untouched");
  eq(fns.stripWrappingQuotes('"mismatch\''), '"mismatch\'', "web: leaves mismatched quotes");
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `node tests/run_web.mjs`
Expected: FAIL with `not found: stripWrappingQuotes`.

- [ ] **Step 3: Implement**

In `web/PCPath_v1.3.0.html`, immediately after `let mappings = loadMappings();` (~L554) add:

```js
function stripWrappingQuotes(s) {
  if (s.length >= 2) {
    const f = s[0], l = s[s.length - 1];
    if ((f === '"' && l === '"') || (f === "'" && l === "'")) return s.slice(1, -1);
  }
  return s;
}
```

Then in `convert()` change the per-line head (~L640) from:

```js
    const trimmed = raw.trim();
    if (!trimmed) return "";

    const line = normalizeMacLike(trimmed);
```

to:

```js
    const trimmed = stripWrappingQuotes(raw.trim());
    if (!trimmed) return "";

    const line = normalizeMacLike(trimmed);
```

- [ ] **Step 4: Run — expect PASS**

Run: `node tests/run_web.mjs`
Expected: all `ok`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add web/PCPath_v1.3.0.html tests/run_web.mjs
git commit -m "feat(web): strip one layer of wrapping quotes on ingest"
```

---

## Task 3: Web — suffix stripping (config + helper + panel)

**Files:**
- Modify: `web/PCPath_v1.3.0.html` (storage, helper, `convert()` wiring, panel input ~L522)
- Test: `tests/run_web.mjs`

- [ ] **Step 1: Add failing test**

Append to `tests/run_web.mjs` before `export`:

```js
// --- Suffix stripping ---
{
  // Build a context with suffixes set, then load the helper against it.
  const src = grab("stripSegmentSuffixes");
  const fn = new Function("stripSuffixes", src + "\nreturn stripSegmentSuffixes;")(["_LA"]);
  eq(fn("E:\\MONA_Moana_LA\\shots\\010"), "E:\\MONA_Moana\\shots\\010", "web: strips _LA on subfolder (win)");
  eq(fn("/Volumes/EDIT/MONA_Moana_LA/shots"), "/Volumes/EDIT/MONA_Moana/shots", "web: strips _LA (mac)");
  eq(fn("E:\\TO GFX_LA\\x"), "E:\\TO GFX\\x", "web: keeps space, strips suffix");
  eq(fn("E:\\TO GFX\\x"), "E:\\TO GFX\\x", "web: no tag unchanged");
  eq(fn("E:\\_LA\\x"), "E:\\_LA\\x", "web: never empties a segment");
  const none = new Function("stripSuffixes", src + "\nreturn stripSegmentSuffixes;")([]);
  eq(none("E:\\MONA_Moana_LA\\x"), "E:\\MONA_Moana_LA\\x", "web: empty suffix list is a no-op");
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `node tests/run_web.mjs`
Expected: FAIL with `not found: stripSegmentSuffixes`.

- [ ] **Step 3: Implement storage + helper**

In `web/PCPath_v1.3.0.html` after `const STORAGE_KEY = "pcpath_mappings";` (~L540) add:

```js
const SUFFIX_KEY = "pcpath_strip_suffixes";
const DEFAULT_SUFFIXES = ["_LA"];

function loadSuffixes() {
  try {
    const saved = localStorage.getItem(SUFFIX_KEY);
    if (saved) { const a = JSON.parse(saved); if (Array.isArray(a)) return a; }
  } catch {}
  return DEFAULT_SUFFIXES.slice();
}

function saveSuffixes(list) {
  localStorage.setItem(SUFFIX_KEY, JSON.stringify(list));
}

let stripSuffixes = loadSuffixes();
```

After the `stripWrappingQuotes` function (from Task 2) add:

```js
function stripSegmentSuffixes(path) {
  if (!stripSuffixes.length) return path;
  return path.replace(/[^\\/]+/g, (seg) => {
    for (const suf of stripSuffixes) {
      if (suf && seg.length > suf.length && seg.endsWith(suf)) return seg.slice(0, -suf.length);
    }
    return seg;
  });
}
```

- [ ] **Step 4: Wire into `convert()`**

Change the `convert()` return (~L645) from:

```js
    return type === "pc" ? pcToMac(line) :
           type === "mac" ? macToPC(line) :
           line;
```

to:

```js
    const converted = type === "pc" ? pcToMac(line) :
                      type === "mac" ? macToPC(line) :
                      line;
    return stripSegmentSuffixes(converted);
```

- [ ] **Step 5: Run helper tests — expect PASS**

Run: `node tests/run_web.mjs`
Expected: all `ok`, exit 0.

- [ ] **Step 6: Add the panel input**

In the mappings panel, after `<div id="mappings-list"></div>` (~L523) add:

```html
    <label class="suffix-row" style="display:flex;gap:.5rem;align-items:center;margin-top:.5rem;">
      <span class="eq">Strip suffixes</span>
      <input id="strip-suffixes-input" class="vol-input" placeholder="_LA, _NY" spellcheck="false">
    </label>
```

After `renderMappings();` (~L808) add:

```js
const suffixInput = document.getElementById("strip-suffixes-input");
suffixInput.value = stripSuffixes.join(", ");
suffixInput.addEventListener("input", () => {
  stripSuffixes = suffixInput.value.split(",").map(s => s.trim()).filter(Boolean);
  saveSuffixes(stripSuffixes);
  if (inputEl.value) outputEl.value = convert(inputEl.value);
});
```

- [ ] **Step 7: Manual smoke check**

Open `web/PCPath_v1.3.0.html` in a browser. Paste `/Volumes/EDIT/MONA_Moana_LA/shots/010`. Confirm output `E:\MONA_Moana\shots\010`. Clear the "Strip suffixes" field; confirm output becomes `E:\MONA_Moana_LA\shots\010`.

- [ ] **Step 8: Commit**

```bash
git add web/PCPath_v1.3.0.html tests/run_web.mjs
git commit -m "feat(web): configurable folder-suffix stripping (default _LA)"
```

---

## Task 4: Mac shell — shared helpers + `STRIP=` parsing in common

**Files:**
- Modify: `pcpath_common.sh` (parse `STRIP=`, add `strip_wrapping_quotes`, `strip_segment_suffixes`)
- Test: `tests/run_shell.sh`

- [ ] **Step 1: Add failing unit tests**

Append to `tests/run_shell.sh` before the final `printf '\n%d failure(s)\n'`:

```bash
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
```

- [ ] **Step 2: Run — expect FAIL**

Run: `bash tests/run_shell.sh`
Expected: FAIL with `strip_wrapping_quotes: command not found` (or unbound `strip_suffixes`).

- [ ] **Step 3: Implement in `pcpath_common.sh`**

Change the top of `pcpath_load_mappings()` (the `vol_names=()` / `drive_letters=()` init, ~L15) to also reset suffix state:

```bash
pcpath_load_mappings() {
    vol_names=()
    drive_letters=()
    strip_suffixes=()
    local _strip_configured=false
```

Inside the `while IFS= read -r line` loop, immediately after the comment/empty skip line (`[[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue`, ~L31) add:

```bash
        # STRIP=<suffix> directive (case-insensitive key)
        if [[ "$line" =~ ^[[:space:]]*[Ss][Tt][Rr][Ii][Pp][[:space:]]*= ]]; then
            local suf="${line#*=}"
            suf="${suf#"${suf%%[![:space:]]*}"}"
            suf="${suf%"${suf##*[![:space:]]}"}"
            _strip_configured=true
            [[ -n "$suf" ]] && strip_suffixes+=("$suf")
            continue
        fi
```

After the `while` loop closes (after `done <<< "$config_data"`, ~L46) add:

```bash
    # Default suffix when none configured.
    if [[ "$_strip_configured" == false ]]; then
        strip_suffixes=("_LA")
    fi
}
```

Then append two helper functions at the end of the file:

```bash
# Remove one layer of matching wrapping quotes (" or ').
strip_wrapping_quotes() {
    local s="$1"
    if [[ ${#s} -ge 2 ]]; then
        local f="${s:0:1}" l="${s: -1}"
        if [[ ( "$f" == '"' && "$l" == '"' ) || ( "$f" == "'" && "$l" == "'" ) ]]; then
            s="${s:1:${#s}-2}"
        fi
    fi
    printf '%s' "$s"
}

# Strip configured suffixes from each '/'-separated segment (exact, case-sensitive,
# only when it leaves a non-empty name; first match wins per segment).
strip_segment_suffixes() {
    local path="$1"
    [[ ${#strip_suffixes[@]} -eq 0 ]] && { printf '%s' "$path"; return; }
    local out="" rest="$path" seg
    while [[ "$rest" == */* ]]; do
        seg="${rest%%/*}"
        rest="${rest#*/}"
        out+="$(_strip_one_segment "$seg")/"
    done
    out+="$(_strip_one_segment "$rest")"
    printf '%s' "$out"
}

_strip_one_segment() {
    local seg="$1" suf
    for suf in "${strip_suffixes[@]}"; do
        [[ -z "$suf" ]] && continue
        if [[ "$seg" == *"$suf" && ${#seg} -gt ${#suf} ]]; then
            printf '%s' "${seg%"$suf"}"
            return
        fi
    done
    printf '%s' "$seg"
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `bash tests/run_shell.sh`
Expected: all helper `ok` lines, `0 failure(s)`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add pcpath_common.sh tests/run_shell.sh
git commit -m "feat(mac): STRIP= parsing + quote/suffix helpers in pcpath_common.sh"
```

---

## Task 5: Mac shell — wire quote + suffix stripping into converters

**Files:**
- Modify: `paste_mac_path.sh` (quote-strip on ingest; suffix-strip on all real outputs)
- Modify: `copy_pc_path.sh` (suffix-strip on output)
- Test: `tests/run_shell.sh`

- [ ] **Step 1: Add failing end-to-end tests**

Append to `tests/run_shell.sh` before the final `printf '\n%d failure(s)\n'`:

```bash
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

# Mac->PC: suffix strip, space kept
bash "$ROOT/copy_pc_path.sh" "/Volumes/EDIT/MONA_Moana_LA/TO GFX/f.mp4" >/dev/null 2>&1
eq "$(clip)" 'E:\MONA_Moana\TO GFX\f.mp4' "shell e2e: Mac->PC suffix + space"
```

- [ ] **Step 2: Run — expect FAIL**

Run: `bash tests/run_shell.sh`
Expected: FAIL on the four e2e lines (quotes/suffix not yet applied).

- [ ] **Step 3: Wire quote strip into `paste_mac_path.sh`**

In the per-line loop, change the trim block (~L143-146) from:

```bash
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
```

to:

```bash
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    line="$(strip_wrapping_quotes "$line")"
    [[ -z "$line" ]] && continue
```

- [ ] **Step 4: Wire suffix strip into `paste_mac_path.sh`**

In `convert_to_mac()`, the smb branch ends with `printf '%s' "/Volumes/$decoded"` (~L51) and the `\Volumes\` branch ends with `printf '%s' "$norm"` (~L61). Change those two to wrap the value:

```bash
        printf '%s' "$(strip_segment_suffixes "/Volumes/$decoded")"
```
and
```bash
        printf '%s' "$(strip_segment_suffixes "$norm")"
```

Leave the UNC-reject `printf '%s' "$pc_path"` (~L68) unchanged (error passthrough, no stripping).

At the function's final line, change `printf '%s' "$mac_path"` (~L121) to:

```bash
    printf '%s' "$(strip_segment_suffixes "$mac_path")"
```

- [ ] **Step 5: Wire suffix strip into `copy_pc_path.sh`**

In `convert_path()`, immediately before the final slash swap `pc_path="${pc_path//\//\\}"` (~L85) add:

```bash
    pc_path="$(strip_segment_suffixes "$pc_path")"
```

(At this point `pc_path` uses `/` between sub-segments — e.g. `E:\MONA_Moana_LA/shots` — so splitting on `/` strips the tag from the segment that carries the `E:\` prefix too, then the existing swap converts `/`→`\`.)

- [ ] **Step 6: Run — expect PASS**

Run: `bash tests/run_shell.sh`
Expected: all `ok`, `0 failure(s)`, exit 0.

- [ ] **Step 7: Commit**

```bash
git add paste_mac_path.sh copy_pc_path.sh tests/run_shell.sh
git commit -m "feat(mac): apply quote + suffix stripping in converters"
```

---

## Task 6: Windows — common helpers (`STRIP=`, quote, suffix)

**Files:**
- Modify: `windows/pcpath_common.ps1` (add `Get-PCPathStripSuffixes`, `Remove-WrappingQuotes`, `Remove-SegmentSuffixes`)
- Test: `tests/run_windows.ps1`

- [ ] **Step 1: Add failing unit tests**

Append to `tests/run_windows.ps1` before the final `Write-Host "`n$script:Fails..."`:

```powershell
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
```

- [ ] **Step 2: Run — expect FAIL**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_windows.ps1`
Expected: FAIL — `Remove-WrappingQuotes` not recognized.

- [ ] **Step 3: Implement in `windows/pcpath_common.ps1`**

Append to `windows/pcpath_common.ps1`:

```powershell
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
```

- [ ] **Step 4: Run — expect PASS**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_windows.ps1`
Expected: all `ok`, `0 failure(s)`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add windows/pcpath_common.ps1 tests/run_windows.ps1
git commit -m "feat(win): STRIP= parsing + quote/suffix helpers in pcpath_common.ps1"
```

---

## Task 7: Windows — wire quote + suffix into converters

**Files:**
- Modify: `windows/convert_to_pc_path.ps1` (quote-strip ingest, suffix-strip output)
- Modify: `windows/copy_mac_path.ps1` (suffix-strip output)
- Test: `tests/run_windows.ps1`

- [ ] **Step 1: Add failing e2e tests**

Append to `tests/run_windows.ps1` before the final `Write-Host`:

```powershell
# Mac->PC quoted input + suffix + space
$o = (& "$Root\windows\convert_to_pc_path.ps1" '"/Volumes/EDIT/MONA_Moana_LA/TO GFX/f.mp4"' | Select-Object -First 1) -replace '^Copied: ', ''
Assert-Eq $o 'E:\MONA_Moana\TO GFX\f.mp4' "win e2e: Mac->PC quote+suffix+space"

# PC->Mac (copy_mac_path) suffix + space
$o2 = (& "$Root\windows\copy_mac_path.ps1" 'E:\MONA_Moana_LA\TO GFX\f.mp4') | Where-Object { $_ -like '/Volumes/*' } | Select-Object -First 1
Assert-Eq $o2 '/Volumes/EDIT/MONA_Moana/TO GFX/f.mp4' "win e2e: PC->Mac suffix+space"
```

- [ ] **Step 2: Run — expect FAIL**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_windows.ps1`
Expected: FAIL on the two e2e lines.

- [ ] **Step 3: Wire `convert_to_pc_path.ps1`**

After `$VolToDrive = Get-PCPathMappings` (~L21) add:

```powershell
$StripSuffixes = Get-PCPathStripSuffixes
```

Change `$Line = $_.Trim()` (~L35) to:

```powershell
    $Line = Remove-WrappingQuotes ($_.Trim())
```

Change the two `$ResultList.Add(...)` calls in the `/Volumes/` match block (~L71 and ~L74) and the non-volume fallback (~L78) to suffix-strip first. Replace:

```powershell
        if ($VolToDrive.ContainsKey($VolName)) {
            $Drive = $VolToDrive[$VolName]
            $ResultList.Add($Drive + ':' + '\' + $Rest)
        } else {
            $ResultList.Add('?(' + $VolName + '):\' + $Rest)
        }
    } else {
        $ResultList.Add(($Line -replace '/', '\'))
    }
```

with:

```powershell
        if ($VolToDrive.ContainsKey($VolName)) {
            $Drive = $VolToDrive[$VolName]
            $ResultList.Add((Remove-SegmentSuffixes ($Drive + ':' + '\' + $Rest) $StripSuffixes))
        } else {
            $ResultList.Add((Remove-SegmentSuffixes ('?(' + $VolName + '):\' + $Rest) $StripSuffixes))
        }
    } else {
        $ResultList.Add((Remove-SegmentSuffixes ($Line -replace '/', '\') $StripSuffixes))
    }
```

- [ ] **Step 4: Wire `copy_mac_path.ps1`**

After `$DriveToVol = Get-PCPathMappings -DriveToVolume` (~L17) add:

```powershell
$StripSuffixes = Get-PCPathStripSuffixes
```

In `Convert-OneToMac`, change the two `return` lines that build `/Volumes/...` (~L33 and L35) to wrap with the helper. Replace the body's `if ($DriveToVol...) { ... } else { ... }` (~L31-36) with:

```powershell
    if ($DriveToVol.ContainsKey($letter)) {
        $vol = $DriveToVol[$letter]
        $res = if ($remainder) { "/Volumes/$vol/$remainder" } else { "/Volumes/$vol" }
    } else {
        $res = if ($remainder) { "/Volumes/?($letter)/$remainder" } else { "/Volumes/?($letter)" }
    }
    return (Remove-SegmentSuffixes $res $StripSuffixes)
```

- [ ] **Step 5: Run — expect PASS**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_windows.ps1`
Expected: all `ok`, `0 failure(s)`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add windows/convert_to_pc_path.ps1 windows/copy_mac_path.ps1 tests/run_windows.ps1
git commit -m "feat(win): apply quote + suffix stripping in converters"
```

---

## Task 8: Windows — drive-label auto-discovery fallback

**Files:**
- Modify: `windows/pcpath_common.ps1` (`Get-LiveVolumeMap`, `Resolve-VolumeFallback`)
- Modify: `windows/convert_to_pc_path.ps1` (volume→letter fallback)
- Modify: `windows/copy_mac_path.ps1` (letter→volume fallback)
- Test: `tests/run_windows.ps1`

- [ ] **Step 1: Add failing unit tests (injectable volume list)**

Append to `tests/run_windows.ps1` before the final `Write-Host`:

```powershell
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
```

- [ ] **Step 2: Run — expect FAIL**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_windows.ps1`
Expected: FAIL — `Resolve-VolumeFallback` not recognized.

- [ ] **Step 3: Implement discovery in `windows/pcpath_common.ps1`**

Append:

```powershell
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
```

- [ ] **Step 4: Wire fallback into `convert_to_pc_path.ps1`**

In the `/Volumes/` match block, replace the `if ($VolToDrive.ContainsKey($VolName)) { ... } else { ... }` (now suffix-wrapped from Task 7) so the `else` tries discovery first:

```powershell
        if ($VolToDrive.ContainsKey($VolName)) {
            $Drive = $VolToDrive[$VolName]
            $ResultList.Add((Remove-SegmentSuffixes ($Drive + ':' + '\' + $Rest) $StripSuffixes))
        } else {
            $Discovered = Resolve-VolumeFallback -Name $VolName -Direction 'VolToLetter'
            if ($Discovered) {
                $ResultList.Add((Remove-SegmentSuffixes ($Discovered + ':' + '\' + $Rest) $StripSuffixes))
            } else {
                $ResultList.Add((Remove-SegmentSuffixes ('?(' + $VolName + '):\' + $Rest) $StripSuffixes))
            }
        }
```

- [ ] **Step 5: Wire fallback into `copy_mac_path.ps1`**

In `Convert-OneToMac`, change the `else` branch (unknown letter) to try discovery:

```powershell
    if ($DriveToVol.ContainsKey($letter)) {
        $vol = $DriveToVol[$letter]
        $res = if ($remainder) { "/Volumes/$vol/$remainder" } else { "/Volumes/$vol" }
    } else {
        $disc = Resolve-VolumeFallback -Name $letter -Direction 'LetterToVol'
        if ($disc) {
            $res = if ($remainder) { "/Volumes/$disc/$remainder" } else { "/Volumes/$disc" }
        } else {
            $res = if ($remainder) { "/Volumes/?($letter)/$remainder" } else { "/Volumes/?($letter)" }
        }
    }
    return (Remove-SegmentSuffixes $res $StripSuffixes)
```

- [ ] **Step 6: Run — expect PASS**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_windows.ps1`
Expected: all `ok` (unit fallback tests pass; e2e tests still pass since static map wins), `0 failure(s)`, exit 0.

- [ ] **Step 7: Commit**

```bash
git add windows/pcpath_common.ps1 windows/convert_to_pc_path.ps1 windows/copy_mac_path.ps1 tests/run_windows.ps1
git commit -m "feat(win): drive-label auto-discovery fallback when mappings miss"
```

---

## Task 9: Wire tests into verify.sh + docs

**Files:**
- Modify: `verify.sh` (run `tests/run_shell.sh` if present)
- Modify: `pcpath_common.sh` header comment (document `STRIP=`)

- [ ] **Step 1: Add a test invocation to `verify.sh`**

Before the final summary block (`printf "\n"` near L97) add:

```bash
# 7. Unit/regression tests (if the tests dir is present)
if [[ -f "$INSTALL_DIR/tests/run_shell.sh" ]]; then
    if bash "$INSTALL_DIR/tests/run_shell.sh" >/dev/null 2>&1; then
        _pass "Shell regression tests passed"
    else
        _fail "Shell regression tests failed (run: bash $INSTALL_DIR/tests/run_shell.sh)"
    fi
fi
```

- [ ] **Step 2: Document `STRIP=` in the config header**

In `pcpath_common.sh`, change the header comment block (top of file) to mention the directive. After the `# Default mappings...` comment, the `PCPATH_DEFAULTS` block stays as-is; add this comment above `pcpath_load_mappings`:

```bash
# Config file format (~/.pcpath_mappings), one directive per line:
#   VOLUME=LETTER   e.g.  EDIT=E
#   STRIP=SUFFIX    e.g.  STRIP=_LA   (strips that suffix from folder names;
#                   any STRIP= line replaces the built-in _LA default)
```

- [ ] **Step 3: Run the full suite — expect PASS**

Run:
```
bash tests/run_shell.sh && node tests/run_web.mjs && powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_windows.ps1
```
Expected: every runner exits 0.

- [ ] **Step 4: Commit**

```bash
git add verify.sh pcpath_common.sh
git commit -m "test+docs: run shell regression in verify.sh; document STRIP= directive"
```

---

## Self-Review

**Spec coverage:**
- Quote stripping (3 platforms) → Tasks 2, 5, 7. ✓
- `STRIP=` config + `_LA` default → Tasks 3, 4, 6. ✓
- Suffix strip helper + both-direction wiring → Tasks 3, 5, 7. ✓
- Windows auto-discovery fallback (static-first, in-memory, placeholder on miss) → Task 8. ✓
- Preservation invariant + canonical witness → Task 1 (all platforms), re-run through Task 9. ✓
- Out-of-scope items (opening, UNC, Mac/web discovery, persistent cache) → not implemented. ✓
- verify.sh + docs → Task 9. ✓

**Type/name consistency:** `strip_suffixes[]`, `strip_wrapping_quotes`, `strip_segment_suffixes`, `_strip_one_segment` (shell); `Get-PCPathStripSuffixes`, `Remove-WrappingQuotes`, `Remove-SegmentSuffixes`, `Get-LiveVolumeMap`, `Resolve-VolumeFallback` with `-Direction VolToLetter|LetterToVol` (PS); `stripSuffixes`, `stripWrappingQuotes`, `stripSegmentSuffixes`, `loadSuffixes`/`saveSuffixes`/`SUFFIX_KEY` (web). Names consistent across the tasks that reference them.

**Placeholder scan:** No TBD/TODO; every code step shows complete code.

**Known caveat carried from spec (intended):** a real folder literally named `something_LA` is also trimmed — accepted trade-off, matches Path Opener.
