# PCPath Installer UX — Design Spec
**Date:** 2026-04-21
**Status:** Approved

## Problem

The current installers complete silently with flat text output. On macOS, Quick Actions require a manual enable step in System Settings that the installer never mentions — the most common reason it appears broken after install. There is also no way for IT to verify the setup is working after the fact.

## Goals

- Installers feel complete and professional (numbered steps, clear success state)
- macOS surfaces the System Settings handoff so Quick Actions actually get enabled
- Both platforms run a self-test at install time to confirm end-to-end conversion works
- IT can re-verify anytime with a standalone verify script

## Out of Scope

- GUI/wizard installers
- Web version changes

---

## Design

### 1. Installer Output Format (both platforms)

Replace flat echo output with numbered steps that print inline as they complete:

```
Installing PCPath...

  [1/4] Creating install directory...   done
  [2/4] Copying scripts...              done
  [3/4] Installing Quick Actions...     done
  [4/4] Writing config...               done (already existed, kept)
```

Each step prints the label first, then appends `done` on the same line after completing. If a step fails, the error appears inline and the script exits with a non-zero code.

### 2. macOS: System Settings Handoff

After the install steps complete, the installer:

1. Prints a clear instruction block:
   ```
   Action required: enable Quick Actions in System Settings
     → Finder → check "Copy as PC Path" and "Convert to Mac Path"
   ```
2. Opens System Settings to the Extensions pane automatically:
   - macOS 13+ (Ventura/Sonoma/Sequoia): `open "x-apple.systempreferences:com.apple.ExtensionsPreferences"`
   - Falls back gracefully if the URL scheme fails (prints manual path instead)
3. Pauses 1 second then continues to the self-test

This is a passive handoff — the installer opens the door, the user checks the two boxes. IT deploying via Kandji does not use `install.sh` — the MDM path handles its own notification (see MDM section below).

### 3. Self-Test (both platforms)

After install steps and the macOS handoff, both installers run a live conversion using the first mapping from the config file:

**macOS output:**
```
Running self-test...
  Input:   /Volumes/CONTENT/Projects/test.mp4
  Output:  K:\Projects\test.mp4
✓  Conversion working
```

**Windows output:**
```
Running self-test...
  Input:   K:\Projects\test.mp4
  Output:  /Volumes/CONTENT/Projects/test.mp4
✓  Conversion working
```

If the test fails (missing config, no valid mappings, script error), it prints what went wrong and exits non-zero. The installer does not consider itself successful if the self-test fails.

### 4. Final Success Block

Both installers end with a compact summary:

```
✓  PCPath installed successfully

Context menu actions:
  Copy as PC Path      Right-click any file or folder in Finder
  Convert to Mac Path  Right-click any file or folder in Finder

Drive mappings: ~/.pcpath_mappings
Edit that file to add or change volume-to-drive-letter mappings.
```

---

## Verify Scripts

Two new standalone scripts: `verify.sh` (macOS) and `windows/verify.ps1` (Windows).

### Behavior

Each check prints a labeled pass/fail line. If any check fails, it prints an actionable note below it.

**macOS example output:**
```
PCPath Verification
───────────────────────────────────────
  [✓] Scripts installed at ~/.pcpath/
  [✓] Config file exists (3 mappings)
  [✓] Quick Actions installed in ~/Library/Services/
  [✗] Quick Action enable state unknown — verify in System Settings > Extensions > Finder
  [✓] Self-test passed: /Volumes/CONTENT → K:\

1 item needs attention. See above.
```

**Windows example output:**
```
PCPath Verification
───────────────────────────────────────
  [✓] Scripts installed at %USERPROFILE%\.pcpath\
  [✓] Config file exists (3 mappings)
  [✓] Registry entries present (5/5)
  [✓] Self-test passed: K:\ → /Volumes/CONTENT

All checks passed.
```

### Checks

| Check | macOS | Windows |
|---|---|---|
| Scripts present at install dir | ✓ | ✓ |
| Config file exists and has ≥1 valid mapping | ✓ | ✓ |
| Workflows in `~/Library/Services/` | ✓ | — |
| Registry keys present (5 keys) | — | ✓ |
| Self-test: live conversion produces expected output | ✓ | ✓ |

**Note on macOS enabled state:** Whether Quick Actions are *enabled* in the Extensions pane is stored in a protected system database and cannot be read programmatically. The verify script checks that the `.workflow` files exist in `~/Library/Services/` (a proxy for "installed") and flags the enable state as unknown, directing IT to confirm visually.

### Exit Codes

- `0` — all checks passed
- `1` — one or more checks failed

This makes the verify scripts usable in IT automation / MDM health checks.

---

## MDM / Kandji Path (`user_setup.sh`)

The Kandji deployment uses `postinstall` → `user_setup.sh` — a completely separate code path that never calls `install.sh`. It runs silently as the logged-in user at login via LaunchAgent. It has the same silent-install gap: workflows land on disk but the user gets no prompt to enable them.

### Changes to `user_setup.sh`

**1. Install log**
Write a timestamped log entry to `~/.pcpath/install.log` on every run (both first install and upgrades). The verify script reads this log.

```
2026-04-21T09:15:00 PCPath 1.2.0 installed via MDM
```

On upgrade runs (version stamp already matches), write nothing — log is only for actual installs.

**2. First-install notification (macOS only)**
After copying files on a first install (not a version-match skip), fire a macOS notification:

```
osascript -e 'display notification "Open System Settings → Extensions → Finder to enable PCPath Quick Actions." with title "PCPath Installed"'
```

This only fires when the workflows were actually written (i.e. `INSTALLED_VERSION != CURRENT_VERSION`). Users who already set it up and get an upgrade do not see a notification.

**3. Install log (shared with `install.sh`)**
Both `install.sh` and `user_setup.sh` write to `~/.pcpath/install.log` on a successful install. The format is the same; `install.sh` writes `installed via manual installer`, `user_setup.sh` writes `installed via MDM`. The verify script reads this log and reports the install method and date. If the log is absent (legacy install before this change), it skips that check silently.

---

## File Changes Summary

| File | Change |
|---|---|
| `install.sh` | Numbered steps, macOS Settings handoff, self-test, install log write, updated success block |
| `windows/install.ps1` | Numbered steps, self-test, updated success block |
| `kandji/user_setup.sh` | Install log write, first-install notification |
| `verify.sh` | New file |
| `windows/verify.ps1` | New file |

No changes to: conversion scripts, config format, `postinstall`, web version, or remote installers.
