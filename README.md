# PCPath

Cross-platform tool for converting file paths between Mac and Windows. Mac users get a right-click option to copy a PC path; Windows users get a right-click option to copy a Mac path. Both platforms share the same config file format so your IT team can set it up once.

## What It Does

| You have | You get |
|---|---|
| `/Volumes/CONTENT/Projects/video.mp4` | `K:\Projects\video.mp4` |
| `K:\Projects\video.mp4` | `/Volumes/CONTENT/Projects/video.mp4` |
| `/Volumes/GFX/Assets/logo.png` | `G:\Assets\logo.png` |
| `/Volumes/EDIT/Sessions/project.prproj` | `E:\Sessions\project.prproj` |
| `/Volumes/THE_NETWORK/Shared/doc.pdf` | `N:\Shared\doc.pdf` |
| `/Volumes/UNKNOWN/file.txt` | `?(UNKNOWN):\file.txt` (placeholder — fill in the drive letter) |

## Default Drive Mappings

| Volume | Drive Letter |
|---|---|
| CONTENT | K: |
| GFX | G: |
| EDIT | E: |
| THE_NETWORK | N: |

These are the defaults. You can customize them — see [Configuration](#configuration) below.

---

## macOS Installation

**Quick install (no git required):**

```bash
curl -fsSL https://raw.githubusercontent.com/marceltheproducer/PCPath/master/remote_install.sh | bash
```

**Or clone and install manually:**

```bash
git clone https://github.com/marceltheproducer/PCPath.git
cd PCPath
./install.sh
```

This installs two Quick Actions and sets up the config file:

| Quick Action | Where it appears | What it does |
|---|---|---|
| **Copy as PC Path** | Finder right-click > Quick Actions | Converts a Mac file path to a PC path and copies to clipboard |
| **Convert to Mac Path** | Select text in any app > right-click > Services | Converts a PC path to a Mac path and copies to clipboard |

### Uninstall (macOS)

```bash
./uninstall.sh
```

---

## Windows Installation

**Quick install (no git required) — open PowerShell and run:**

```powershell
irm https://raw.githubusercontent.com/marceltheproducer/PCPath/master/windows/remote_install.ps1 | iex
```

**Or clone and install manually:**

```powershell
git clone https://github.com/marceltheproducer/PCPath.git
cd PCPath\windows
.\install.ps1
```

This adds a **"Copy as Mac Path"** entry to the right-click context menu for files and folders.

There's also a bonus utility for when a Mac user sends you a path:

```powershell
# Converts a Mac path on your clipboard to a PC path
~\.pcpath\convert_to_pc_path.ps1
```

### Uninstall (Windows)

```powershell
.\uninstall.ps1
```

---

## Usage

### On Mac

**Copying a PC path for a Windows user:**
1. Right-click a file or folder on a mounted volume in Finder
2. Go to **Quick Actions** > **Copy as PC Path**
3. Paste the Windows path wherever you need it

**Converting a PC path you received:**
1. Select the PC path text in any app (Slack, email, etc.)
2. Right-click > **Services** > **Convert to Mac Path**
3. The Mac path is now on your clipboard — paste it into Finder's "Go to Folder" (Cmd+Shift+G)

### On Windows

**Copying a Mac path for a Mac user:**
1. Right-click a file or folder
2. Click **Copy as Mac Path**
3. Paste the Mac path wherever you need it

**Converting a Mac path you received:**
1. Copy the Mac path to your clipboard
2. Run `~\.pcpath\convert_to_pc_path.ps1` in PowerShell
3. The PC path is now on your clipboard

---

## Configuration

Both platforms read mappings from the same config file format:

| Platform | Config file location |
|---|---|
| macOS | `~/.pcpath_mappings` |
| Windows | `%USERPROFILE%\.pcpath_mappings` |

The file format is one mapping per line:

```
# Lines starting with # are comments
CONTENT=K
GFX=G
EDIT=E
THE_NETWORK=N
```

To add a new volume, just add a line. Changes take effect immediately — no reinstall required.

### IT / Manual Deployment

To set this up for your team without MDM:
1. Install PCPath on each machine (Mac or Windows)
2. Distribute a standard `pcpath_mappings` config file to `~/.pcpath_mappings` (macOS) or `%USERPROFILE%\.pcpath_mappings` (Windows)
3. If mappings change, just update the config file — no reinstall needed

### Kandji / MDM Deployment (macOS)

For pushing PCPath to multiple Macs via Kandji (or any MDM that supports `.pkg` files):

**1. Prerequisites**

- A Mac with Xcode command-line tools installed
- An [Apple Developer Program](https://developer.apple.com/programs/) membership ($99/year)
- Two Developer ID certificates (created at [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/certificates/list)):
  - **Developer ID Application** — signs the Automator workflows
  - **Developer ID Installer** — signs the .pkg

**2. One-time notarization setup**

Store your Apple credentials in the keychain so the build script can notarize automatically:

```bash
xcrun notarytool store-credentials "PCPath" \
  --apple-id "you@example.com" \
  --team-id "ABCDE12345" \
  --password "<app-specific-password>"
```

Generate an app-specific password at [appleid.apple.com](https://appleid.apple.com/account/manage) under **Sign-In and Security > App-Specific Passwords**.

**3. Build the signed installer**

```bash
git clone https://github.com/marceltheproducer/PCPath.git
cd PCPath

export DEVELOPER_ID_APP="Developer ID Application: Your Name (TEAMID)"
export DEVELOPER_ID_INSTALLER="Developer ID Installer: Your Name (TEAMID)"
export NOTARY_PROFILE="PCPath"

./kandji/build_pkg.sh 1.0.0 --sign
```

This code-signs the Automator workflows (hardened runtime), signs the .pkg with your Developer ID Installer certificate, submits to Apple for notarization, and staples the ticket. The output is `kandji/PCPath-1.0.0.pkg`, ready for distribution.

For local testing without signing, omit `--sign`:

```bash
./kandji/build_pkg.sh 1.0.0
```

**2. Upload to Kandji**

1. Go to **Library > Add New > Custom App**
2. Set install type to **Package**
3. Upload `PCPath-1.0.0.pkg`
4. Assign to your desired device blueprint(s)

**3. (Optional) Add the uninstall script**

In the Custom App settings, paste the contents of `kandji/uninstall_mdm.sh` as the uninstall script. This cleanly removes PCPath from all users on the machine.

**4. (Optional) Push a company-wide config**

To standardize drive mappings, create a Kandji **Custom Script** that writes `~/.pcpath_mappings` to each user's home directory. The config file format is the same one documented above.

**How the package works:**

| Component | Location | Purpose |
|---|---|---|
| Shared scripts & workflows | `/usr/local/pcpath/` | Installed by the .pkg (system-wide) |
| LaunchAgent | `/Library/LaunchAgents/com.pcpath.user-setup.plist` | Triggers per-user setup at login |
| Per-user files | `~/.pcpath/`, `~/Library/Services/` | Copied from system dir on first login |
| Config | `~/.pcpath_mappings` | Created from template on first login (not overwritten on upgrades) |

**Upgrading:** Bump the version number (`./kandji/build_pkg.sh 1.1.0`) and re-upload. The per-user setup automatically re-runs on next login when it detects a new version.

---

## How It Works

- **macOS**: Automator Quick Actions call shell scripts installed at `~/.pcpath/`
- **Windows**: PowerShell scripts installed at `%USERPROFILE%\.pcpath\`, triggered via context menu registry entries
- **Config**: Both platforms read the same `pcpath_mappings` format so mappings stay in sync
- **Unmapped volumes**: If a volume/drive isn't in the config, the path uses `?` as a placeholder with the volume/drive name included (e.g. `?(UNKNOWN):\folder\file.txt`) so it's obvious what needs mapping

## File Structure

```
PCPath/
├── remote_install.sh                   # macOS one-liner installer
├── install.sh                          # macOS installer
├── uninstall.sh                        # macOS uninstaller
├── pcpath_common.sh                    # Shared config-loading logic
├── copy_pc_path.sh                     # Mac → PC conversion
├── paste_mac_path.sh                   # PC → Mac conversion
├── pcpath_mappings.default             # Default config template
├── Copy as PC Path.workflow/           # Finder Quick Action
├── Convert to Mac Path.workflow/       # Text Services Quick Action
├── kandji/
│   ├── build_pkg.sh                    # Builds .pkg for Kandji/MDM deployment
│   ├── entitlements.plist              # Hardened runtime entitlements for workflows
│   ├── postinstall                     # pkg postinstall script (runs as root)
│   ├── user_setup.sh                   # Per-user setup (runs at login)
│   ├── com.pcpath.user-setup.plist     # LaunchAgent for login-time setup
│   └── uninstall_mdm.sh               # MDM uninstall script
└── windows/
    ├── remote_install.ps1              # Windows one-liner installer
    ├── install.ps1                     # Windows installer
    ├── uninstall.ps1                   # Windows uninstaller
    ├── copy_mac_path.ps1               # PC → Mac conversion (context menu)
    └── convert_to_pc_path.ps1          # Mac → PC conversion (clipboard utility)
```
