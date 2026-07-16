# UNC Input Support — Design

**Date:** 2026-07-15
**Status:** Approved (Marcel, 2026-07-15)
**Release scope:** Full release — Windows installer 2.3 → 2.4, web v1.4.0 → v1.5.0, sync all 4 locations, portal Version bump. Mac app pkg (1.0.1 → 1.0.2) deferred to next build-Mac session; Swift source + tests ship in this change.

## Problem

UNC paths (`\\server\share\...`) are rejected or mangled by every converter surface.
Users paste them from Explorer address bars, Teams messages, and IT docs. The
information content is identical to the already-supported `smb://server/share/...`
form: the host is irrelevant, the share name equals the Mac volume name.

## Design

Treat UNC as another normalize-early input shape, mirroring the existing `smb://`
handling exactly: **drop the host, share = volume name.**

```
\\calamedia\GFX\_library\Tech  →  /Volumes/GFX/_library/Tech   (PC→Mac surfaces)
                               →  G:\_library\Tech             (Mac→PC clipboard verb, via existing volume→drive mapping)
```

Unknown shares flow through the existing fallbacks: live-volume discovery, then
`?(SHARE)` placeholder. Suffix stripping (`STRIP=`, default `_LA`) applies as with
every other shape.

### Edge rules (identical across all five implementations)

| Input | Behavior |
|---|---|
| `\\host\share\rest` | Convert. Host may be bare or FQDN. `rest` may mix `\` and `/`. |
| `\\host\share` | Convert → `/Volumes/share`. |
| `\\host` (no share) | Pass through unchanged (nothing to convert). |
| `\\?\...`, `\\.\...` device paths | Pass through unchanged. |
| `//host/share` (forward-slash UNC) | NOT converted — ambiguous with a valid POSIX path. Existing per-surface behavior kept. |
| `\\Volumes\X\...` | Existing typo-normalization keeps precedence (same result either way). |
| URL-decoding | None. UNC is not URL-encoded (unlike smb://). |

### Per-surface changes

| Surface | File | Change |
|---|---|---|
| Windows clipboard verb (Mac→PC) | `windows/convert_to_pc_path.ps1` | UNC branch after smb + `\Volumes` normalization → `/Volumes/share/rest` → existing drive-mapping pipeline |
| Windows right-click "Copy as Mac Path" | `windows/copy_mac_path.ps1` | `Convert-OneToMac` gains UNC branch (files browsed via `\\server\share\` now convert); error message no longer claims UNC unsupported |
| Mac legacy shell (PC→Mac) | `paste_mac_path.sh` | Replace UNC reject+warn with conversion; bare `\\host` / device paths keep old warn+pass-through |
| Mac app/extension | `macapp/Sources/PCPathKit/PathConverter.swift` `pcToMac` | Replace UNC reject with conversion; `//` prefix keeps pass-through |
| Web converter | `web/PCPath_v1.4.0.html` → renamed `PCPath_v1.5.0.html` | `pcToMac` gains UNC branch (`detectType` already classifies `\\` input as PC) |

### Alternatives rejected

- **Server-aware mappings enabling UNC output** (`GFX=G=calamedia`): config format
  change across 4 platforms, no current need. YAGNI.
- **Skip the Mac app to avoid a rebuild:** breaks the four-implementation parity
  invariant HANDOFF maintains.

## Testing

TDD against the existing harnesses: `tests/run_windows.ps1`, `tests/run_shell.sh`
(Git Bash), `tests/run_web.mjs` (node). Swift cases added to
`macapp/Tests/PathConverterTests.swift`; they execute at next build-Mac session.

Cases (each harness, adapted to its direction):
1. `\\calamedia\GFX\_library\Tech` → mapped conversion
2. FQDN host: `\\calamedia.domain.tld\CONTENT\Projects\video.mp4`
3. Unknown share → `?(SHARE)` fallback
4. Share only, no rest: `\\host\EDIT`
5. Suffix strip still applies: `\\calamedia\GFX\foo_LA\bar`
6. Device path `\\?\C:\x` unchanged
7. Precedence: `\\Volumes\EDIT\x` → `/Volumes/EDIT/x`
8. Bare `\\host` unchanged
9. Mixed separators in rest: `\\host\GFX\a/b\c`

## Release

1. Implement + tests green (PS, shell, web)
2. Update HANDOFF.md path-shape coverage table + versions
3. Rename web file to `PCPath_v1.5.0.html`, bump internal version strings
4. `windows\sync.ps1` — bumps installer to 2.4, rebuilds NSIS exe, syncs
   `_Out` / GitHub clone / `G:\_library`, commits + pushes
5. Verify web file + renamed artifacts propagate to all 4 locations
6. Portal Notion row: Version → 2.4
7. Deferred: Mac `PCPath-app-1.0.2.pkg` (needs build Mac; Swift source ready)
