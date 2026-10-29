#!/bin/bash
# install.sh — One-command installer for MacCleanUp (maccleanup).
# Usage: bash install.sh

set -euo pipefail

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${CYAN}"
cat <<'EOF'
  __  __            ___ _                 _   _
 |  \/  | __ _  ___ / __\ | ___  __ _ _ _ | | | |_ __
 | |\/| |/ _` |/ _ \ |  | |/ _ \/ _` | ' \| |_| | '_ \
 | |  | | (_| | (_) | |__| |  __/ (_| | | | |  _  | |_) |
 |_|  |_|\__,_|\___/ \___|_|\___|\__,_|_| |_|_| |_| .__/
                                                   |_|
EOF
echo -e "${NC}"
echo -e "${BOLD}Installing MacCleanUp (maccleanup)...${NC}\n"

# Verify macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo -e "${YELLOW}Warning: MacCleanUp is designed specifically for macOS.${NC}"
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

# Make the executable runnable
chmod +x "${PROJECT_DIR}/maccleanup"
chmod +x "${PROJECT_DIR}/lib/clean/clean_tui.py" 2>/dev/null || true

# Create symlink
ln -sf "${PROJECT_DIR}/maccleanup" "${BIN_DIR}/maccleanup"

echo -e "  ${GREEN}✓${NC} Linked executable to ${BIN_DIR}/maccleanup"

# Setup default configuration
CONFIG_DIR="$HOME/.config/maccleanup"
mkdir -p "$CONFIG_DIR"
if [[ ! -f "${CONFIG_DIR}/config.yaml" && -f "${PROJECT_DIR}/config/defaults.yaml" ]]; then
    cp "${PROJECT_DIR}/config/defaults.yaml" "${CONFIG_DIR}/config.yaml"
    echo -e "  ${GREEN}✓${NC} Created configuration file at ${CONFIG_DIR}/config.yaml"
fi

# Ensure ~/.local/bin is in PATH
SHELL_NAME="$(basename "$SHELL")"
RC_FILE="$HOME/.zshrc"
[[ "$SHELL_NAME" == "bash" ]] && RC_FILE="$HOME/.bashrc"

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$RC_FILE" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC_FILE"
        echo -e "  ${GREEN}✓${NC} Added ${BIN_DIR} to ${RC_FILE}"
    fi
    echo -e "\n${YELLOW}Note:${NC} Run ${BOLD}source ${RC_FILE}${NC} or restart your terminal to reload your PATH."
fi

echo -e "\n${BOLD}${GREEN}Installation successful!${NC}"
echo -e "You can now launch the utility from anywhere by running:"
echo -e "  ${CYAN}maccleanup${NC}\n"
