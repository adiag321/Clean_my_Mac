#!/bin/bash
# lib/optimize/maintenance.sh — System maintenance: DNS flush, QuickLook, icon cache,
#                               Spotlight, Launch Services, periodic maintenance scripts.
# Source this file; do not execute directly.

run_optimize() {
    MCU_TOTAL_FREED_KB=0
    MCU_ITEMS_CLEANED=0

    ui_banner "Optimize Mac" "Refresh system caches, services, and maintenance tasks"
    ui_disk_space

    # ── DNS cache ──────────────────────────────────────────────────────────────
    ui_section "DNS Cache"
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        ui_dry "DNS cache flush" "?" "dscacheutil -flushcache + killall mDNSResponder"
    else
        sudo dscacheutil -flushcache 2>/dev/null && sudo killall -HUP mDNSResponder 2>/dev/null || true
        ui_cleaned "DNS cache" "flushed"
        mcu_oplog "flushed" "DNS cache"
    fi

    # ── QuickLook thumbnail cache ──────────────────────────────────────────────
    ui_section "QuickLook"
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        ui_dry "QuickLook thumbnail cache" "?" "qlmanage -r cache"
    else
        qlmanage -r cache 2>/dev/null || true
        qlmanage -r 2>/dev/null || true
        ui_cleaned "QuickLook thumbnail cache" "reset"
        mcu_oplog "reset" "QuickLook cache"
    fi

    # ── Dock / Finder icon cache ───────────────────────────────────────────────
    ui_section "Icon Cache"
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        ui_dry "Dock/Finder icon cache" "?" "removes com.apple.dock.iconcache + iconservices*"
    else
        find /private/var/folders -maxdepth 4 -iname "com.apple.dock.iconcache" -exec rm -f -- {} + 2>/dev/null || true
        find /private/var/folders -maxdepth 4 -iname "com.apple.iconservices*"  -exec rm -rf -- {} + 2>/dev/null || true
        killall Dock   2>/dev/null || true
        killall Finder 2>/dev/null || true
        ui_cleaned "Dock/Finder icon cache" "rebuilt (brief flicker is normal)"
        mcu_oplog "rebuilt" "icon cache"
    fi

    # ── Launch Services database ───────────────────────────────────────────────
    ui_section "Launch Services"
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        ui_dry "Launch Services database" "?" "lsregister -kill -r -domain local -domain system -domain user"
    else
        if command -v lsregister >/dev/null 2>&1; then
            lsregister -kill -r -domain local -domain system -domain user 2>/dev/null || true
        else
            local lsreg
            lsreg=$(/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister)
            "$lsreg" -kill -r -domain local -domain system -domain user 2>/dev/null || true
        fi
        ui_cleaned "Launch Services database" "rebuilt"
        mcu_oplog "rebuilt" "Launch Services database"
    fi

    # ── Spotlight ──────────────────────────────────────────────────────────────
    ui_section "Spotlight"
    mdutil -s / 2>/dev/null | while IFS= read -r line; do
        echo -e "  ${GRAY}${line}${NC}"
    done

    if [[ "${REINDEX_SPOTLIGHT:-0}" -eq 1 ]]; then
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            ui_dry "Spotlight full reindex" "?" "sudo mdutil -E /"
        else
            sudo mdutil -E / 2>/dev/null || true
            ui_cleaned "Spotlight" "reindex triggered (may take minutes)"
            mcu_oplog "reindexed" "Spotlight /"
        fi
    fi

    # ── Periodic maintenance scripts ───────────────────────────────────────────
    ui_section "Periodic Maintenance"
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        ui_dry "Periodic scripts" "?" "sudo periodic daily weekly monthly"
    else
        sudo periodic daily weekly monthly 2>/dev/null || true
        ui_cleaned "Periodic maintenance scripts" "daily/weekly/monthly run"
        mcu_oplog "ran" "periodic maintenance scripts"
    fi

    # ── Time Machine local snapshots ───────────────────────────────────────────
    # APFS keeps local snapshots even without an external Time Machine disk;
    # thinning reclaims space without touching any actual backup.
    ui_section "Time Machine Local Snapshots"
    if command -v tmutil >/dev/null 2>&1; then
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            ui_dry "Local snapshots" "?" "sudo tmutil thinlocalsnapshots root 999999999999 4"
        else
            if sudo tmutil thinlocalsnapshots / 999999999999 4 >/dev/null 2>&1; then
                ui_cleaned "Local snapshots" "thinned"
                mcu_oplog "thinned" "Time Machine local snapshots"
            else
                ui_skipped "Local snapshots" "thinning failed or none to thin"
            fi
        fi
    else
        ui_skipped "Local snapshots" "tmutil not found"
    fi

    # ── Session temp directory ──────────────────────────────────────────────────
    ui_section "Temporary Files"
    if [[ -n "${TMPDIR:-}" && -d "$TMPDIR" ]]; then
        safe_clean_dir "$TMPDIR" "Session temp directory"
    else
        ui_skipped "Session temp directory" "TMPDIR not set"
    fi

    echo ""
    echo -e "${BOLD}$(printf '%.0s═' {1..70})${NC}"
    echo -e "  ${GREEN}Optimize complete${NC}"
    echo -e "${BOLD}$(printf '%.0s═' {1..70})${NC}"
    echo ""
}
