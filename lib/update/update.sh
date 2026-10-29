#!/bin/bash
# lib/update/update.sh — Self-updater for MacCleanUp / maccleanup.
# Source this file; do not execute directly.

run_update() {
    ui_banner "MacCleanUp — Self-Updater" "Checking for updates..."
    
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

    if [[ -d "${script_dir}/.git" ]] && command -v git >/dev/null 2>&1; then
        echo -e "${GRAY}Repository path: ${script_dir}${NC}"
        echo -e "Fetching latest updates via git..."
        if git -C "$script_dir" pull --ff-only 2>/dev/null; then
            echo -e "${GREEN}${ICON_OK} Successfully updated to the latest version.${NC}"
        else
            echo -e "${YELLOW}${ICON_WARN} Could not fast-forward update. You may have local modifications.${NC}"
            echo -e "${GRAY}Run 'git -C \"${script_dir}\" status' to inspect.${NC}"
        fi
    else
        echo -e "${YELLOW}${ICON_WARN} Not a git checkout (${script_dir}).${NC}"
        echo -e "Check your installation source or repository for updates."
    fi
}
