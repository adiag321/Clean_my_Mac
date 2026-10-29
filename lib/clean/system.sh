#!/bin/bash
# lib/clean/system.sh — System-level cleanup: /private/var/log, diagnostics (requires sudo).
# Source this file; do not execute directly.

clean_system_logs() {
    ui_section "System Logs (sudo)"

    safe_clean_dir "/private/var/log/powermanagement" "Power Management Logs"
    safe_clean_dir "/private/var/log/DiagnosticMessages" "Diagnostic Messages"
    safe_clean_dir "/private/var/log/asl"             "Apple System Log"

    shopt -s nullglob
    local p
    for p in /private/var/log/*.bz2 /private/var/log/*.gz; do
        safe_remove_path "$p" "System Log Archive"
    done
    shopt -u nullglob
}

# System diagnostic traces (tens of MB per file)
clean_system_diagnostics() {
    ui_section "System Diagnostics (sudo)"

    local found=0
    local diag_dir="/private/var/db/diagnostics"

    if [[ ! -d "$diag_dir" ]]; then
        ui_skipped "System diagnostics" "not found"
        return 0
    fi

    # Only remove trace files older than 7 days to avoid removing active ones
    shopt -s nullglob
    local f
    while IFS= read -r -d '' f; do
        safe_remove_path "$f" "System diagnostic trace"
        found=1
    done < <(find "$diag_dir" -maxdepth 3 \
        \( -name "*.tracev3" -o -name "*.logarchive" \) \
        -mtime +7 -print0 2>/dev/null)
    shopt -u nullglob

    [[ $found -eq 0 ]] && ui_skipped "System diagnostics" "no stale traces found (>7 days)"
}

clean_system_library_logs() {
    ui_section "System Library Logs (sudo)"

    if [[ -d "/Library/Logs" ]]; then
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            ui_dry "System library logs" "$(path_size_h /Library/Logs)" "/Library/Logs"
        else
            sudo find "/Library/Logs" -mindepth 1 -exec rm -rf -- {} + 2>/dev/null || true
            ui_cleaned "/Library/Logs" "cleaned"
            mcu_oplog "cleaned" "/Library/Logs"
        fi
    fi
}
