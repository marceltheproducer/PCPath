# PCPath

Cross-platform tool for converting file paths between Mac and Windows. Both platforms get right-click actions to convert paths in both directions — copy a file's path for the other OS, or convert a path from the clipboard. Both platforms share the same config file format so your IT team can set it up once.

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

## Web Version

Don't want to install anything? Use the **web version** for quick path conversions in your browser:

**[Open PCPath Web App](web/PCPath_v1.2.0.html)** (works offline, no installation needed)

**Features:**
- 🌐 Works in any modern browser
- 💾 No installation required
- 🎨 Dark/light themes + custom colors
- ⚡ Auto-copy to clipboard (optional)
- 📱 Responsive design (works on mobile)
- 🔒 All data stays local (no server uploads)
- ⚙️ Customizable drive mappings (saved in browser)

**How to use:**
1. Open the HTML file in your browser (or bookmark it)
2. Paste a path (PC or Mac format)
3. Get the converted path instantly
4. Toggle "Auto-copy" for automatic clipboard copying

**Tip:** You can save the HTML file to your desktop or bookmark it for quick access. All settings are saved in your browser's localStorage.

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

| Quick Action | What it does |
|---|---|
| **Copy as PC Path** | Converts the selected file's path to a PC path and copies to clipboard |
| **Convert to Mac Path** | Converts a PC path on your clipboard to a Mac path |

Both appear in **Finder right-click > Quick Actions**.

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

This adds two context menu entries:

| Context Menu Action | Where it appears | What it does |
|---|---|---|
| **Copy as Mac Path** | Right-click any file or folder | Converts the selected file's path to a Mac path and copies to clipboard |
| **Convert to PC Path** | Right-click empty space in a folder or desktop | Converts a Mac path on your clipboard to a PC path |

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
1. Copy the PC path to your clipboard (from Slack, email, etc.)
2. Right-click any file in Finder > **Quick Actions** > **Convert to Mac Path**
3. The Mac path is now on your clipboard — paste it into Finder's "Go to Folder" (Cmd+Shift+G)

### On Windows

**Copying a Mac path for a Mac user:**
1. Right-click a file or folder
2. Click **Copy as Mac Path**
3. Paste the Mac path wherever you need it

**Converting a Mac path you received:**
1. Copy the Mac path to your clipboard
2. Right-click empty space in a folder or on the desktop > **Convert to PC Path**
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

**4. Upload to Kandji**

1. Go to **Library > Add New > Custom App**
2. Set install type to **Package**
3. Upload `PCPath-1.0.0.pkg`
4. Assign to your desired device blueprint(s)

**5. (Optional) Add the uninstall script**

In the Custom App settings, paste the contents of `kandji/uninstall_mdm.sh` as the uninstall script. This cleanly removes PCPath from all users on the machine.

**6. (Optional) Push a company-wide config**

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
- **Web**: Standalone HTML file that runs entirely in your browser with localStorage for settings
- **Config**: Both platforms read the same `pcpath_mappings` format so mappings stay in sync
- **Unmapped volumes**: If a volume/drive isn't in the config, the path uses `?` as a placeholder with the volume/drive name included (e.g. `?(UNKNOWN):\folder\file.txt`) so it's obvious what needs mapping

---

## Troubleshooting

### macOS Issues

**Quick Actions don't appear in Finder**
- Run `killall Finder` in Terminal to restart Finder
- Check if workflows are installed: `ls ~/Library/Services/`
- Try removing and reinstalling: `./uninstall.sh && ./install.sh`
- Make sure you right-click on an actual file/folder (not empty space)

**"Permission denied" when running scripts**
- Check file permissions: `ls -l ~/.pcpath/`
- Make scripts executable: `chmod +x ~/.pcpath/*.sh`

**Paths not converting correctly**
- Check your config file: `cat ~/.pcpath_mappings`
- Make sure format is `VOLUME=LETTER` (one per line)
- No spaces around the `=` sign
- Volume names are case-sensitive
- Check for Windows line endings (CRLF) - should be Unix (LF)

**Getting `?(UNKNOWN):` in output**
- The volume/drive isn't in your config file
- Add the mapping to `~/.pcpath_mappings`
- Example: `MYVOLUME=X`

### Windows Issues

**Context menu entries don't appear**
- Restart Explorer: Open Task Manager → Restart "Windows Explorer"
- Run PowerShell as Administrator and reinstall: `.\install.ps1`
- Check registry entries exist: Look in `HKEY_CLASSES_ROOT\*\shell\`

**"Execution policy" error when installing**
- Run PowerShell as Administrator
- Run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
- Try installing again

**Converted path is wrong**
- Check your config: `type %USERPROFILE%\.pcpath_mappings`
- Make sure format is `VOLUME=LETTER`
- Drive letters should be single characters (A-Z)

**UNC paths not supported**
- PCPath only works with mapped drive letters (e.g. `K:\`)
- Convert UNC paths (`\\server\share`) to mapped drives first
- Use Windows "Map Network Drive" feature

### Web Version Issues

**Auto-copy not working**
- Your browser may have blocked clipboard access
- Click the page first to give it focus
- Check browser permissions for clipboard access
- Use the manual "Copy" button instead

**Settings not saving**
- Check if localStorage is enabled in your browser
- Private/Incognito mode may not persist settings
- Try clearing browser cache and reloading

**Theme colors look wrong**
- Click the "Auto" button under Font # to reset font color
- Try a preset theme first, then customize
- Clear localStorage and refresh: Open DevTools → Application → Local Storage → Delete

### General Issues

**Config file format errors**
```
# ✅ CORRECT
CONTENT=K
GFX=G

# ❌ WRONG
CONTENT = K        # No spaces around =
content=k          # Volume name should match exact case
CONTENT=KK         # Drive letter should be single character
```

**Volume/drive not mounting**
- Make sure the network volume is actually mounted before converting
- On Mac: Check Finder sidebar or run `ls /Volumes/`
- On Windows: Check "This PC" or run `net use` in cmd

**Need to update mappings for whole team**
- Update the `.pcpath_mappings` file on each machine
- Or use MDM/group policy to push updated config
- Changes take effect immediately (no reinstall needed)

**Still having issues?**
- Check the [GitHub Issues](https://github.com/marceltheproducer/PCPath/issues) page
- Open a new issue with your OS version and config file contents
- Include the exact error message you're seeing

---

## File Structure

```
PCPath/
├── tool.yaml                           # CI/CD manifest (name, version, permissions, security)
├── .gitignore                          # Git ignore rules
├── remote_install.sh                   # macOS one-liner installer
├── install.sh                          # macOS installer
├── uninstall.sh                        # macOS uninstaller
├── pcpath_common.sh                    # Shared config-loading logic
├── copy_pc_path.sh                     # Mac → PC conversion
├── paste_mac_path.sh                   # PC → Mac conversion
├── pcpath_mappings.default             # Default config template
├── Copy as PC Path.workflow/           # Finder Quick Action
├── Convert to Mac Path.workflow/       # Finder Quick Action (clipboard)
├── kandji/
│   ├── build_pkg.sh                    # Builds .pkg for Kandji/MDM deployment
│   ├── entitlements.plist              # Hardened runtime entitlements for workflows
│   ├── postinstall                     # pkg postinstall script (runs as root)
│   ├── user_setup.sh                   # Per-user setup (runs at login)
│   ├── com.pcpath.user-setup.plist     # LaunchAgent for login-time setup
│   └── uninstall_mdm.sh               # MDM uninstall script
├── web/
│   └── PCPath_v1.2.0.html              # Standalone web version (browser-based)
└── windows/
    ├── remote_install.ps1              # Windows one-liner installer
    ├── install.ps1                     # Windows installer
    ├── uninstall.ps1                   # Windows uninstaller
    ├── copy_mac_path.ps1               # PC → Mac conversion (context menu)
    └── convert_to_pc_path.ps1          # Mac → PC conversion (context menu)
```
