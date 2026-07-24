# Mac build session — ship PCPath app 1.0.2 (+ Kandji pilot)

Brief for a Claude Code session running **on the build Mac**. Written
2026-07-23 by the Windows-side session. Read `HANDOFF.md` (repo root) for full
project context; this file is the task list.

## Context in three sentences

The Windows/web/shell sides of PCPath shipped **UNC input support** on
2026-07-15 (Windows installer 2.4, web v1.5.0, all live on the CREATE Portal).
The same UNC support is **already committed** to the Swift conversion core
(`macapp/Sources/PCPathKit/PathConverter.swift` + tests), but the shipped Mac
app/extension pkg is still **1.0.1**, built before that change. Your job:
build, sign, notarize, and distribute **1.0.2**, and — if a pilot Mac is
available — run the Kandji pilot that's been pending since June.

**Everything Mac-copyable was already synced from Windows** (shell scripts in
`_Out` and `G:` match the repo). Only the things that genuinely need a Mac are
left.

## Prerequisites (should already exist on this machine — verify, don't set up blind)

- Full Xcode selected (`xcode-select -p` → `/Applications/Xcode.app/...`)
- XcodeGen (`which xcodegen`)
- Keychain: **Developer ID Application** + **Developer ID Installer** certs,
  Team `6M993C5R86`
- notarytool keychain profile (name used for 1.0.1 was `PCPath` per
  `macapp/README.md`; `xcrun notarytool history --keychain-profile PCPath` to
  confirm)
- A clone of `github.com/marceltheproducer/PCPath` at current `origin/main`
  (commit `48ea082` or later). **Work in a local clone, not the SMB-mounted
  repo.** Never `git reset --hard` — see HANDOFF / project memory; it has
  destroyed uncommitted work before.

## Task 1 — build + ship 1.0.2

1. **Pull latest `main`, confirm clean.** The UNC work is in commits
   `4390e09` (Swift) and neighbors; nothing new to write unless tests fail.
2. **Run the tests first** (no Xcode needed):
   ```bash
   cd macapp
   swiftc Sources/PCPathKit/PathConverter.swift Tests/PathConverterTests.swift Tests/main.swift -o /tmp/t && /tmp/t
   ```
   Also run the shell parity suite from the repo root: `bash tests/run_shell.sh`.
   All green before building.
3. **Bump the version in `macapp/project.yml`:** `MARKETING_VERSION: "1.0.1"`
   → `"1.0.2"` (line ~13; update its trailing comment too). `build.sh` also
   overrides the version at build time, but the spec should match what ships.
4. **Build + sign + notarize + staple:**
   ```bash
   cd macapp
   export DEVELOPER_ID_APP="Developer ID Application: <as in keychain> (6M993C5R86)"
   export TEAM_ID="6M993C5R86"
   export NOTARY_PROFILE="PCPath"
   ./build.sh 1.0.2 --notarize          # → macapp/dist/PCPath.app
   ```
   `build.sh` already sets `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` (the
   1.0.1 notarization fix — don't remove). Entitlements come from
   `project.yml` via xcodegen; **never hand-edit the `.entitlements` files.**
5. **Package:**
   ```bash
   cd ..
   export DEVELOPER_ID_INSTALLER="Developer ID Installer: <as in keychain> (6M993C5R86)"
   ./kandji/build_app_pkg.sh 1.0.2 --sign   # → PCPath-app-1.0.2.pkg
   ```
   The script builds a **non-relocatable** pkg (`BundleIsRelocatable false`)
   — keep it that way so it always installs to `/Applications`.
6. **Verify before distributing:**
   ```bash
   xcrun stapler validate PCPath-app-1.0.2.pkg
   spctl -a -vv -t install PCPath-app-1.0.2.pkg
   ```
   Ideally also: install locally, right-click a file under `/Volumes/...`,
   confirm the three verbs appear and that **Convert to Mac Path** accepts a
   UNC path (`\\calamedia\gfx\_library\test` → `/Volumes/GFX/_library/test`).
7. **Distribute the pkg** (it is **gitignored** — `kandji/*.pkg` — and must
   never be committed):
   - `/Volumes/DEV/General Dev/Design/_Out/PCPath/mac/PCPath-app-1.0.2.pkg`
   - `/Volumes/GFX/_library/Tech/DevOps/PCPath/PCPath-app-1.0.2.pkg`

   **Leave `PCPath-app-1.0.1.pkg` in place in both folders** — the portal's
   Mac Path field points at the 1.0.1 filename until it's flipped (step 9).
8. **Commit + push** (to `origin/main` on GitHub): the `project.yml` version
   bump, plus a HANDOFF.md update (versions table: Mac app → 1.0.2 shipped;
   move the "1.0.2 rebuild pending" open item to done). Windows side pulls
   this back into the `V:` source-of-truth repo afterward.
9. **Portal Mac Path field** — the Notion row (page id
   `d506eaff-e20a-40c0-8079-1a8ecc909776`, R&D Tech Development Tracker) has
   `Mac Path = //calamedia/GFX/_library/Tech/DevOps/PCPath/PCPath-app-1.0.1.pkg`.
   If this session has Notion MCP access, update it to the `1.0.2` filename,
   then delete the 1.0.1 pkg from both share folders. If not, **report back**
   — the Windows-side session will flip the field (do NOT touch the row's
   `Version` field; that belongs to the hosted Windows build pipeline).

## Task 2 (if a pilot Mac is available) — Kandji pilot

Steps live in `/Volumes/DEV/General Dev/Design/_Out/PCPath/IRU-DEPLOY.md`.
Summary: upload the pkg (use 1.0.2 if Task 1 succeeded) to Kandji as a
**Custom App**, push to one clean Mac, and check whether the right-click
verbs appear **without** the user flipping the Finder-extension toggle in
System Settings → General → Login Items & Extensions.

- Appears with no toggle → ship org-wide.
- Toggle required → add the managed **Login Items & Extensions** profile for
  Team `6M993C5R86` per IRU-DEPLOY.md, re-test, then ship.

## Report back (for the Windows-side session / next HANDOFF update)

- 1.0.2 built + notarized? Any deviations from the steps above?
- Pkg copied to both share folders? 1.0.1 removed or retained?
- Portal Mac Path field updated, or still pending Windows-side?
- Pilot outcome (no-toggle / profile-needed / not run)?
- Delete this file (`macapp/MAC-SESSION-1.0.2.md`) in the wrap-up commit once
  everything above is done — HANDOFF.md is the durable record.
