# PCPath ⇄ Path Opener Parity — Design

**Date:** 2026-06-10
**Status:** Approved (pending spec review)
**Source of comparison:** Mike's "Path Opener" (`PATH_HANDLING.md`, v1.1.0)

## Background

Mike's Path Opener is a Windows GUI app that **opens** a pasted path in Explorer.
PCPath is a bidirectional clipboard **converter** (Mac ⇄ Windows) shipped on three
platforms:

- **Mac** — shell scripts (`paste_mac_path.sh`, `copy_pc_path.sh`, `copy_names.sh`)
  invoked by Automator Quick Actions, plus `pcpath_common.sh`.
- **Windows** — PowerShell (`windows/convert_to_pc_path.ps1`, `windows/copy_mac_path.ps1`)
  plus `windows/pcpath_common.ps1`.
- **Web** — single-file `web/PCPath_v1.3.0.html` (no install, no filesystem).

A feature comparison found PCPath already handles **more** input shapes than Path
Opener (smb:// with %-decode, bare volume names, `\Volumes\` backslash variants,
multi-line/multi-select batch, graceful `?(NAME)` placeholders, and both directions).
Path Opener leads in three areas, which this design brings to PCPath. Path Opener's
filesystem-aware behaviors (open in Explorer, select-vs-folder, `looks_like_file`
parent-folder resolution, existence checks) are **explicitly out of scope** — PCPath
is a converter, not an opener.

### Note on the "bad path" report (resolved)

During design, a path that lost a space (`TO GFX` → `TOGFX`) and dropped its filename
was attributed to PCPath. Investigation proved otherwise: the shipped Windows converter
and web v1.3.0 both preserve the space and filename on that exact input, and no
historical web version even emits `E:\…` for a `\Volumes\…` input (that normalization
only exists in v1.3.0). The output matched Path Opener's parent-folder resolution. Root
cause was confirmed by the user as user error. No PCPath fix was required — but it
motivated the **folder-name preservation invariant** below.

## Goals

1. **Quote stripping** — tolerate paths wrapped in `"`/`'` (e.g. Windows "Copy as path").
2. **Strip-suffix support** — remove configured region tags (e.g. London's `_LA`) from
   folder-name segments during conversion.
3. **Auto-discovery fallback (Windows only)** — resolve unknown volume↔letter via live
   drive labels when the mappings file has no entry.

All three must uphold the preservation invariant.

## Folder-name preservation invariant

Conversion may ONLY:

- (a) map the volume name ↔ drive letter,
- (b) swap slash direction (`/` ↔ `\`),
- (c) strip **one** matched wrapping quote pair at the very ends of a line,
- (d) remove an **exact configured suffix** from the **end** of a segment.

It must NEVER alter the body of a segment — no internal-space removal, no `\s`-class
trimming, no normalization of segment contents, no dropping of segments (filenames
included). Suffix matching compares **exact bytes/characters** (`segment ends-with
"_LA"`), never a regex that could span or consume whitespace.

## Feature 1 — Quote stripping

**Where:** the three **free-text ingest** points only:

- `paste_mac_path.sh` — per-line, after the existing whitespace trim (~L143).
- `windows/convert_to_pc_path.ps1` — per-line, after `.Trim()` (~L35).
- `web/PCPath_v1.3.0.html` `convert()` — per-line, after `raw.trim()` (~L640).

NOT on `copy_pc_path.sh` / `copy_mac_path.ps1` / `copy_names.sh` — those receive real
paths from Finder/Explorer and never carry quotes.

**Behavior:** after whitespace trim, if the line starts and ends with the **same** quote
character (`"` or `'`), remove exactly that one outer pair. Single layer only. Mirrors
Path Opener's `.strip('"').strip("'")`.

- `"E:\Project\comp.aep"` → `E:\Project\comp.aep`
- `'/Volumes/EDIT/x'` → `/Volumes/EDIT/x`
- `"E:\a\"weird"\b"` → unchanged body — only the outer pair is removed.

## Feature 2 — Strip-suffix support

**Config:** new repeatable `STRIP=<suffix>` directive lines in `~/.pcpath_mappings`
(one suffix per line), parsed alongside the existing `VOLUME=LETTER` lines. `_LA` ships
as a **built-in default** so London works with no config edit. The web version exposes
the suffix list in its mappings panel / stored config (no file on disk).

- `pcpath_common.sh` `pcpath_load_mappings()` — populate a new `strip_suffixes[]` array;
  ignore `STRIP=` when splitting `VOLUME=LETTER`.
- `windows/pcpath_common.ps1` `Get-PCPathMappings` — return suffixes (new return shape
  or companion function `Get-PCPathStripSuffixes`).
- Web — add suffixes to the stored mappings model.

**Behavior** — a shared `strip_segment_suffixes(path)` helper applied **after** the
volume↔letter conversion, to each `\`-separated (or `/`-separated, pre-swap) segment:

- For each segment, if it **ends with** a configured suffix AND removing it leaves a
  **non-empty** name, drop the suffix. Case-sensitive, end-of-segment, first match wins
  per segment. Identical semantics to Path Opener's `strip_segment_suffixes()`.
- Applied in **both** directions and on all ingest paths: `paste_mac_path.sh`,
  `copy_pc_path.sh`, both Windows scripts, and web. (It is local-normalization of an
  ingested foreign path; the tag is a remote-naming artifact.)

Examples (suffix `_LA`):

- `/Volumes/EDIT/MONA_Moana_LA/shots/010` → `E:\MONA_Moana\shots\010`
- `E:\MONA_Moana_LA\shots` → `/Volumes/EDIT/MONA_Moana/shots`
- `…/TO GFX_LA/…` → `…/TO GFX/…` (space kept, only `_LA` removed)
- `…/TO GFX/…` → unchanged

**Accepted trade-off:** a folder legitimately named `something_LA` is also trimmed. This
matches Path Opener and is acceptable for the London workflow. Tag wins.

## Feature 3 — Auto-discovery fallback (Windows only)

A drive letter is a Windows concept; only a Windows machine can read its own drive
labels to bridge label ↔ letter. Mac has no Windows drive letters to discover (mapping
is pure cross-machine convention) and web has no filesystem — both stay file-only.

**Where:** both Windows scripts, via a shared helper in `windows/pcpath_common.ps1`.

**Behavior:**

1. The static `~/.pcpath_mappings` map is consulted **first** (preserves current
   behavior and lets users override discovery).
2. On a **miss** — unknown volume name (Mac→Win) or unknown drive letter (Win→Mac) —
   lazily run **one** `Get-Volume` scan, build label↔letter pairs from live, labeled
   drives, and retry the lookup.
3. The scan result is held **in memory for the invocation only** (no persistent
   `volumes.json`). Each script run is a fresh process; the in-memory cache only avoids
   rescanning within a single multi-path conversion.
4. Still a miss → today's `?(NAME)` / `?(LETTER)` placeholder (unchanged).

Discovery is case-insensitive on the label (consistent with the existing
`OrdinalIgnoreCase` map).

## Testing

Extend `verify.sh` self-test and add focused cases across platforms. All assertions run
against the as-shipped code AND after the three features land:

- **Preservation witness (canonical):**
  `\Volumes\EDIT\EastofEden_ESED\Media\GFX\TO GFX\20260610\tim_edt_trl_Beauty_v5_wip04_wm.mp4`
  → `E:\EastofEden_ESED\Media\GFX\TO GFX\20260610\tim_edt_trl_Beauty_v5_wip04_wm.mp4`
  — space intact, filename intact, both directions.
- **Quote stripping:** `"…/TO GFX/…"` → quotes gone, space kept; single-quote variant;
  unbalanced quotes leave body untouched.
- **Suffix stripping:** `_LA` on a subfolder (both directions); space + suffix combined
  (`TO GFX_LA` → `TO GFX`); no-tag path unchanged; suffix that would empty a segment is
  NOT stripped.
- **Config parsing:** `STRIP=` lines load into the suffix list (shell + PS); default
  `_LA` present when no config; `VOLUME=LETTER` lines unaffected.
- **Windows auto-discovery:** unit with a mockable `Get-Volume` — unknown volume resolves
  via live label; static map still wins when present; placeholder on total miss.
- **Web:** inline assertions mirroring the shell/PS cases.

## Out of scope

- Opening paths in Explorer/Finder; select-vs-folder; `looks_like_file`; existence
  checks; parent-folder resolution.
- UNC support (PCPath deliberately rejects UNC — no drive-letter equivalent).
- Auto-discovery on Mac or web.
- Persistent volume cache file.

## Files touched

- `pcpath_common.sh` — parse `STRIP=`, expose `strip_suffixes[]`, add
  `strip_segment_suffixes`.
- `paste_mac_path.sh` — quote strip; apply suffix strip post-conversion.
- `copy_pc_path.sh` — apply suffix strip post-conversion.
- `windows/pcpath_common.ps1` — parse `STRIP=`; suffix helper; `Get-Volume` discovery helper.
- `windows/convert_to_pc_path.ps1` — quote strip; suffix strip; discovery fallback.
- `windows/copy_mac_path.ps1` — suffix strip; discovery fallback.
- `web/PCPath_v1.3.0.html` — quote strip; suffix strip; suffix config in panel.
- `verify.sh` — extended self-test / regression cases.
