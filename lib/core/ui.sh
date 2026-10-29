#!/bin/bash
# lib/core/ui.sh — Shared terminal UI helpers: colors, icons, spinners, sections.
# Source this file; do not execute directly.

# ── Color & style codes ──────────────────────────────────────────────────────
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" == "" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    BOLD='\033[1m'
    DIM='\033[2m'
    GRAY='\033[0;90m'
    NC='\033[0m'     # Reset / No Color
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' BOLD='' DIM='' GRAY='' NC=''
fi

# ── Status icons ─────────────────────────────────────────────────────────────
ICON_OK="✓"
ICON_SKIP="◎"
ICON_WARN="⚠"
ICON_ARROW="➤"
ICON_DRY="⟳"
ICON_BULLET="·"

CURRENT_CATEGORY="General"

# ── Section header ────────────────────────────────────────────────────────────
# Usage: ui_section "Browser Caches"
ui_section() {
    CURRENT_CATEGORY="$1"
    if [[ -z "${SCAN_COLLECT_FILE:-}" ]]; then
        echo ""
        echo -e "${BOLD}${ICON_ARROW} ${1}${NC}"
    fi
}

# ── Print a cleaned item line ─────────────────────────────────────────────────
# Usage: ui_cleaned "Chrome cache" "1.2GB" [path]
ui_cleaned() {
    local label="$1" size="$2" path="${3:-}"
    local folder_name=""
    if [[ -n "$path" ]]; then
        folder_name=$(basename "$path" 2>/dev/null || echo "")
    fi

    local display_name="$label"
    if [[ -n "$folder_name" && "$folder_name" != "$label" && "$label" != *"$folder_name"* ]]; then
        display_name="${label}: ${folder_name}"
    fi

    echo -e "  ${GREEN}${ICON_OK}${NC} ${display_name} ${GRAY}· ${size}${NC}"
}

# ── Print a dry-run preview item ──────────────────────────────────────────────
ui_dry() {
    local label="$1" size="$2" path="${3:-}"
    local folder_name=""
    if [[ -n "$path" ]]; then
        folder_name=$(basename "$path" 2>/dev/null || echo "")
    fi

    local display_name="$label"
    if [[ -n "$folder_name" && "$folder_name" != "$label" && "$label" != *"$folder_name"* ]]; then
        display_name="${label}: ${folder_name}"
    fi

    if [[ "${DEBUG:-false}" == "true" && -n "$path" ]]; then
        echo -e "  ${CYAN}${ICON_DRY}${NC} ${display_name} ${GRAY}· ${size} · ${path}${NC}"
    else
        echo -e "  ${CYAN}${ICON_DRY}${NC} ${display_name} ${GRAY}· ${size}${NC}"
    fi
}

# ── Print a skipped item ──────────────────────────────────────────────────────
ui_skipped() {
    local label="$1" reason="$2"
    echo -e "  ${GRAY}${ICON_SKIP} ${label} · skipped${reason:+ (${reason})}${NC}"
}

# ── Print a warning ───────────────────────────────────────────────────────────
ui_warn() {
    echo -e "  ${YELLOW}${ICON_WARN}${NC} ${1}"
}

# ── Print a fatal error and exit ──────────────────────────────────────────────
ui_fatal() {
    echo -e "${RED}ERROR: ${1}${NC}" >&2
    exit 1
}

# ── Top banner ────────────────────────────────────────────────────────────────
ui_banner() {
    local title="$1" subtitle="${2:-}"
    echo ""
    echo -e "${BOLD}${title}${NC}"
    [[ -n "$subtitle" ]] && echo -e "${GRAY}${subtitle}${NC}"
    echo ""
}

# ── Summary footer ────────────────────────────────────────────────────────────
# Usage: ui_summary_footer 4608 97 4   (total_kb items_cleaned categories)
ui_summary_footer() {
    local total_kb="${1:-0}" items="${2:-0}" cats="${3:-0}"
    local total_mb=$(( total_kb / 1024 ))
    echo ""
    echo -e "${BOLD}$(printf '%.0s═' {1..70})${NC}"
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo -e "  ${CYAN}Dry-run complete — nothing was deleted${NC}"
        echo -e "  ${GRAY}Reclaimable: ~${total_mb}MB across ${items} items in ${cats} categories${NC}"
    else
        echo -e "  ${GREEN}Cleanup complete${NC}"
        echo -e "  ${GRAY}Freed: ~${total_mb}MB ${ICON_BULLET} Items: ${items} ${ICON_BULLET} Categories: ${cats}${NC}"
    fi
    echo -e "${BOLD}$(printf '%.0s═' {1..70})${NC}"
    echo ""
}

# ── Disk space one-liner ──────────────────────────────────────────────────────
ui_disk_space() {
    local avail total pct
    avail=$(df -h / 2>/dev/null | awk 'NR==2{print $4}')
    total=$(df -h / 2>/dev/null | awk 'NR==2{print $2}')
    pct=$(df -h  / 2>/dev/null | awk 'NR==2{print $5}')
    echo -e "${GRAY}⚙ Free space: ${avail} of ${total} (${pct} used)${NC}"
}
