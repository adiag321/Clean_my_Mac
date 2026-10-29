#!/bin/bash
# lib/clean/clean.sh — Deep cache, log, and leftover clean orchestrator.
# Coordinates all clean submodules, config extra_paths, and system tasks.
# Source this file; do not execute directly.

SCRIPT_DIR_CLEAN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all submodules
# shellcheck source=/dev/null
source "${SCRIPT_DIR_CLEAN}/user.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR_CLEAN}/apps.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR_CLEAN}/browsers.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR_CLEAN}/dev.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR_CLEAN}/packages.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR_CLEAN}/orphans.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR_CLEAN}/system.sh"

clean_custom_extra_paths() {
    if [[ ${#MCU_CLEAN_EXTRA_PATHS[@]} -eq 0 ]]; then
        return 0
    fi

    ui_section "Custom Config Paths"
    local item path mode min_size label
    for item in "${MCU_CLEAN_EXTRA_PATHS[@]}"; do
        IFS='|' read -r path mode min_size <<< "$item"
        [[ -z "$path" ]] && continue
        label=$(path_label "$path")

        case "$mode" in
            remove)
                safe_remove_path "$path" "Custom (remove): ${label}"
                ;;
            clean_if_large)
                min_size="${min_size:-0}"
                safe_clean_dir_if_large "$path" "$min_size" "Custom (>=${min_size}MB): ${label}"
                ;;
            clean|*)
                safe_clean_dir "$path" "Custom: ${label}"
                ;;
        esac
    done
}

clean_ds_store_trees() {
    local ds_trees=()
    local in_clean=false in_ds=false line tree
    if [[ -f "$MCU_CONFIG_FILE" ]]; then
        while IFS= read -r line; do
            [[ "$line" =~ ^clean: ]] && { in_clean=true; continue; }
            if $in_clean && [[ "$line" =~ ^[a-zA-Z] ]]; then
                in_clean=false; in_ds=false; continue
            fi
            if $in_clean; then
                [[ "$line" =~ ^[[:space:]]{2}ds_store_trees: ]] && { in_ds=true; continue; }
                if $in_ds; then
                    [[ "$line" =~ ^[[:space:]]{2}[a-zA-Z] ]] && { in_ds=false; continue; }
                    if [[ "$line" =~ ^[[:space:]]{4}-[[:space:]]*(.+) ]]; then
                        tree="${BASH_REMATCH[1]}"
                        tree="${tree/#\~/$HOME}"
                        ds_trees+=("$tree")
                    fi
                fi
            fi
        done < "$MCU_CONFIG_FILE"
    fi

    if [[ ${#ds_trees[@]} -eq 0 ]]; then
        return 0
    fi

    ui_section ".DS_Store File Sweep"
    local t count
    for t in "${ds_trees[@]}"; do
        [[ -d "$t" ]] || continue
        count=$(find "$t" -name ".DS_Store" -type f 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$count" -gt 0 ]]; then
            if [[ "${DRY_RUN:-false}" == "true" ]]; then
                ui_dry ".DS_Store files in $(basename "$t")" "${count} files" "$t"
            else
                find "$t" -name ".DS_Store" -type f -delete 2>/dev/null || true
                ui_cleaned ".DS_Store files in $(basename "$t")" "${count} removed"
                mcu_oplog "removed .DS_Store" "$t" "${count} files"
            fi
        fi
    done
}

scan_all_candidates() {
    local do_system="${DO_SYSTEM:-false}"
    local do_orphans="${DO_ORPHANS:-true}"

    clean_user_essentials
    clean_apple_services
    clean_ai_ide_apps
    clean_productivity_apps
    clean_microsoft_office
    clean_messaging_apps
    clean_browsers
    clean_xcode
    clean_jetbrains
    clean_steam
    clean_docker
    if [[ "${DO_DEEP_CLEAN:-false}" == "true" ]]; then
        clean_command_line_tools
    fi
    clean_package_managers
    clean_ghost_apps

    if [[ "$do_orphans" == "true" ]]; then
        clean_orphaned_app_data
    fi

    clean_gpu_caches
    clean_trash
    clean_custom_extra_paths
    clean_ds_store_trees

    if [[ "$do_system" == "true" ]]; then
        echo ""
        echo -e "${BOLD}${CYAN}=== System-level Cleanup (Requires sudo) ===${NC}"
        if [[ $EUID -ne 0 ]]; then
            echo -e "${GRAY}Requesting administrator privileges for /private/var/log and diagnostics...${NC}"
            sudo -v || true
        fi
        clean_system_logs
        clean_system_diagnostics
        clean_system_library_logs
    fi
}

run_clean() {
    local do_system="${DO_SYSTEM:-false}"
    local do_orphans="${DO_ORPHANS:-true}"
    local interactive_mode=false

    # Use interactive dropdown TUI if running interactively in terminal and not auto-yes or dry-run flag
    if [[ -t 0 && -t 1 && "${DRY_RUN:-false}" != "true" && "${AUTO_YES:-0}" -eq 0 ]]; then
        interactive_mode=true
    fi

    if $interactive_mode; then
        local tsv_scan approved_items
        tsv_scan=$(mktemp)
        approved_items=$(mktemp)

        echo -e "${GRAY}Scanning system, application, and browser caches...${NC}"
        SCAN_COLLECT_FILE="$tsv_scan"
        scan_all_candidates
        unset SCAN_COLLECT_FILE

        # Launch interactive dropdown TUI
        python3 "${SCRIPT_DIR_CLEAN}/clean_tui.py" "$tsv_scan" "$approved_items"
        local tui_res=$?

        if [[ $tui_res -eq 0 && -s "$approved_items" ]]; then
            MCU_TOTAL_FREED_KB=0
            MCU_ITEMS_CLEANED=0
            oplog_start "clean"
            ui_banner "Clean Mac" "Cleaning selected items..."

            local target_path mode label size_h size_kb
            while IFS=$'\t' read -r target_path mode label size_h size_kb; do
                [[ -z "$target_path" ]] && continue
                if [[ "$mode" == "remove" ]]; then
                    # Guard maccleanup directory
                    [[ "$target_path" == *"/Library/Logs/maccleanup"* ]] && continue
                    rm -rf -- "$target_path" 2>/dev/null || true
                    ui_cleaned "$label" "$size_h" "$target_path"
                    mcu_oplog "removed" "$target_path" "$size_h"
                else
                    find "$target_path" -mindepth 1 -not -path "*/maccleanup" -not -path "*/maccleanup/*" -exec rm -rf -- {} + 2>/dev/null || true
                    ui_cleaned "$label" "$size_h" "$target_path"
                    mcu_oplog "cleaned" "$target_path" "$size_h"
                fi
                MCU_TOTAL_FREED_KB=$(( MCU_TOTAL_FREED_KB + ${size_kb:-0} ))
                MCU_ITEMS_CLEANED=$(( MCU_ITEMS_CLEANED + 1 ))
            done < "$approved_items"

            ui_summary_footer "$MCU_TOTAL_FREED_KB" "$MCU_ITEMS_CLEANED" 12
            ui_disk_space
            oplog_end "$MCU_TOTAL_FREED_KB" "$MCU_ITEMS_CLEANED"
            rm -f "$tsv_scan" "$approved_items"
            return 0
        else
            echo -e "${GRAY}Clean cancelled. Nothing was deleted.${NC}"
            rm -f "$tsv_scan" "$approved_items"
            return 0
        fi
    fi

    # Non-interactive CLI / Dry-run execution
    MCU_TOTAL_FREED_KB=0
    MCU_ITEMS_CLEANED=0
    MCU_ITEMS_SKIPPED=0

    ui_banner "Clean Mac" "Deep cache, log, leftover, and package cleanup"
    ui_disk_space

    oplog_start "clean"

    # Check override setting from config
    local override_val
    override_val=$(yaml_get "$MCU_CONFIG_FILE" "clean.override" 2>/dev/null || echo "false")

    if [[ "$override_val" == "true" ]]; then
        echo -e "${YELLOW}Config override is TRUE: skipping built-in paths and running custom extra_paths only.${NC}"
        clean_custom_extra_paths
    else
        scan_all_candidates
    fi

    ui_summary_footer "$MCU_TOTAL_FREED_KB" "$MCU_ITEMS_CLEANED" 12
    ui_disk_space

    oplog_end "$MCU_TOTAL_FREED_KB" "$MCU_ITEMS_CLEANED"
}

