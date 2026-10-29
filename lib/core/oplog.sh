#!/bin/bash
# lib/core/oplog.sh — Operation log: record every destructive action.
# Source this file; do not execute directly.

MCU_OPLOG_DIR="${HOME}/Library/Logs/maccleanup"
MCU_OPLOG_FILE=""
MCU_OPLOG_ENABLED=true

# ── Initialize op-log for this run ────────────────────────────────────────────
oplog_init() {
    [[ "${MCU_NO_OPLOG:-}" == "1" ]] && {
        MCU_OPLOG_ENABLED=false; return 0
    }
    mkdir -p "$MCU_OPLOG_DIR" 2>/dev/null || true
    MCU_OPLOG_FILE="${MCU_OPLOG_DIR}/operations.log"
}

# ── Record an operation ────────────────────────────────────────────────────────
# Usage: mcu_oplog <action> <path> [size]
mcu_oplog() {
    $MCU_OPLOG_ENABLED || return 0
    [[ -z "$MCU_OPLOG_FILE" ]] && return 0
    local action="$1" path="$2" size="${3:-}"
    local ts
    ts=$(date '+%Y-%m-%dT%H:%M:%S')
    [[ -d "$MCU_OPLOG_DIR" ]] || mkdir -p "$MCU_OPLOG_DIR" 2>/dev/null || true
    printf '%s\t%s\t%s\t%s\n' "$ts" "$action" "${size:-?}" "$path" >> "$MCU_OPLOG_FILE" 2>/dev/null || true
}

# ── Record the start of a run ─────────────────────────────────────────────────
oplog_start() {
    $MCU_OPLOG_ENABLED || return 0
    [[ -z "$MCU_OPLOG_FILE" ]] && return 0
    local cmd="$1"
    local ts
    ts=$(date '+%Y-%m-%dT%H:%M:%S')
    [[ -d "$MCU_OPLOG_DIR" ]] || mkdir -p "$MCU_OPLOG_DIR" 2>/dev/null || true
    printf '\n%s\tRUN_START\t-\tcmp %s (dry_run=%s)\n' "$ts" "$cmd" "${DRY_RUN:-false}" >> "$MCU_OPLOG_FILE" 2>/dev/null || true
}

# ── Record the end of a run ───────────────────────────────────────────────────
oplog_end() {
    $MCU_OPLOG_ENABLED || return 0
    [[ -z "$MCU_OPLOG_FILE" ]] && return 0
    local freed_kb="$1" items="$2"
    local ts
    ts=$(date '+%Y-%m-%dT%H:%M:%S')
    [[ -d "$MCU_OPLOG_DIR" ]] || mkdir -p "$MCU_OPLOG_DIR" 2>/dev/null || true
    printf '%s\tRUN_END\t~%sMB\t%s items\n' "$ts" "$(( freed_kb / 1024 ))" "$items" >> "$MCU_OPLOG_FILE" 2>/dev/null || true
}

# ── Print or clear history ──────────────────────────────────────────────────────
# Usage: oplog_history [--json|--clear]
oplog_history() {
    if [[ "${1:-}" == "--clear" ]]; then
        if [[ -f "$MCU_OPLOG_FILE" ]]; then
            > "$MCU_OPLOG_FILE"
            echo -e "${GREEN}${ICON_OK} Operation log cleared.${NC}"
        else
            echo "No operation log found to clear."
        fi
        return 0
    fi

    local json_mode=false
    [[ "${1:-}" == "--json" ]] && json_mode=true

    if [[ ! -f "$MCU_OPLOG_FILE" ]] || [[ ! -s "$MCU_OPLOG_FILE" ]]; then
        echo "No operation log found at: $MCU_OPLOG_FILE"
        return 0
    fi

    if $json_mode; then
        echo "["
        local first=true
        while IFS=$'\t' read -r ts action size path; do
            [[ -z "$ts" ]] && continue
            $first || echo ","
            first=false
            printf '  {"timestamp":"%s","action":"%s","size":"%s","path":"%s"}' \
                "$ts" "$action" "$size" "$path"
        done < "$MCU_OPLOG_FILE"
        echo ""
        echo "]"
    else
        echo -e "${BOLD}MacCleanUp — Operation History${NC} (${MCU_OPLOG_FILE})"
        echo ""
        printf "%-20s  %-12s  %-10s  %s\n" "TIMESTAMP" "ACTION" "SIZE" "TARGET"
        printf "%-20s  %-12s  %-10s  %s\n" "--------------------" "------------" "----------" "----------------------------------------"
        while IFS=$'\t' read -r ts action size path; do
            [[ -z "$ts" ]] && continue
            printf "%-20s  %-12s  %-10s  %s\n" "$ts" "$action" "$size" "$path"
        done < "$MCU_OPLOG_FILE"
    fi
}

