#!/bin/bash
# uninstall.sh — Clean uninstaller for MacCleanUp (maccleanup).
# Usage: bash uninstall.sh

set -euo pipefail

BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/maccleanup"
LOG_DIR="$HOME/Library/Logs/maccleanup"

echo "Uninstalling MacCleanUp (maccleanup)..."

rm -f "${BIN_DIR}/maccleanup"
echo "  ✓ Removed ${BIN_DIR}/maccleanup"

read -r -p "Do you also want to remove your config and logs (~/.config/maccleanup, ~/Library/Logs/maccleanup)? [y/N] " reply
if [[ "$reply" =~ ^[Yy]$ ]]; then
    rm -rf "$CONFIG_DIR" "$LOG_DIR"
    echo "  ✓ Removed ${CONFIG_DIR} and ${LOG_DIR}"
fi

echo "Uninstallation complete."
