#!/bin/bash
# uninstall_mdm.sh — MDM uninstall script for Kandji
# Upload this as the uninstall script in Kandji Custom App settings.
# Runs as root.

# Remove LaunchAgent
LAUNCH_AGENT="/Library/LaunchAgents/com.pcpath.user-setup.plist"
if [[ -f "$LAUNCH_AGENT" ]]; then
    # Unload for all logged-in users
    for uid_dir in /Users/*/Library; do
        username=$(basename "$(dirname "$uid_dir")")
        uid=$(id -u "$username" 2>/dev/null) || continue
        launchctl bootout "gui/$uid/com.pcpath.user-setup" 2>/dev/null
    done
    rm -f "$LAUNCH_AGENT"
fi

# Remove system-wide files
rm -rf /usr/local/pcpath

# Remove per-user files for all users
for home_dir in /Users/*/; do
    username=$(basename "$home_dir")
    [[ "$username" == "Shared" || "$username" == ".localized" ]] && continue
    rm -rf "${home_dir}.pcpath"
    rm -rf "${home_dir}Library/Services/Copy as PC Path.workflow"
    rm -rf "${home_dir}Library/Services/Convert to Mac Path.workflow"
    # Leave .pcpath_mappings (user config) in place
done

exit 0
