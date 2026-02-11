#!/bin/bash
# PCPath Remote Installer for macOS
# Usage: curl -fsSL https://raw.githubusercontent.com/marceltheproducer/PCPath/master/remote_install.sh | bash

set -e

REPO_URL="https://github.com/marceltheproducer/PCPath/archive/refs/heads/master.tar.gz"
TMPDIR_PATH="$(mktemp -d)"

cleanup() {
    rm -rf "$TMPDIR_PATH"
}
trap cleanup EXIT

echo "Downloading PCPath..."
curl -fsSL "$REPO_URL" | tar -xz -C "$TMPDIR_PATH"

# The archive extracts to PCPath-master/
cd "$TMPDIR_PATH/PCPath-master"

echo ""
bash ./install.sh
