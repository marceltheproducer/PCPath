# PCPath

A macOS Quick Action that adds a **"Copy as PC Path"** option to the right-click menu in Finder. It converts Mac file paths to Windows-style paths and copies them to your clipboard.

## What It Does

When you right-click a file or folder on a mounted server volume, it converts the Mac path to a Windows/PC path:

| Mac Path | PC Path |
|---|---|
| `/Volumes/CONTENT/Projects/video.mp4` | `K:\Projects\video.mp4` |
| `/Volumes/GFX/Assets/logo.png` | `G:\Assets\logo.png` |
| `/Volumes/EDIT/Sessions/project.prproj` | `E:\Sessions\project.prproj` |
| `/Volumes/THE_NETWORK/Shared/doc.pdf` | `N:\Shared\doc.pdf` |

## Drive Letter Mappings

| Volume | Drive Letter |
|---|---|
| CONTENT | K: |
| GFX | G: |
| EDIT | E: |
| THE_NETWORK | N: |

## Installation

### Quick Install (recommended)

1. Double-click the **`Copy as PC Path.workflow`** file
2. macOS will ask if you want to install the Quick Action — click **Install**
3. Done! Right-click any file in Finder and look under **Quick Actions** for **"Copy as PC Path"**

### Manual Install

1. Copy the `Copy as PC Path.workflow` folder to:
   ```
   ~/Library/Services/
   ```
2. The Quick Action will appear in Finder's right-click menu under **Quick Actions**

## Usage

1. In Finder, right-click (or Control-click) any file or folder on a mounted volume
2. Go to **Quick Actions** > **Copy as PC Path**
3. The converted Windows path is now on your clipboard — just paste it wherever you need it

## Adding More Drive Mappings

To add more volume-to-drive-letter mappings, edit the script inside the workflow:

1. Open Automator (`/Applications/Automator.app`)
2. Open `~/Library/Services/Copy as PC Path.workflow`
3. In the shell script, add entries to the two arrays:
   ```bash
   declare -a vol_names=("CONTENT" "GFX" "EDIT" "THE_NETWORK" "NEW_VOLUME")
   declare -a drive_letters=("K" "G" "E" "N" "X")
   ```
4. Save the workflow

Alternatively, edit `copy_pc_path.sh` in this repo and reinstall the workflow.
