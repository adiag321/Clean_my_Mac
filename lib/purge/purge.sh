#!/bin/bash
# lib/purge/purge.sh — Dev artifact purge: finds stale node_modules, target, .build, etc.
# Source this file; do not execute directly.

run_dev_purge() {
    local artifact_names=("${MCU_ARTIFACT_NAMES[@]:-node_modules target .build dist __pycache__ .dart_tool .venv venv}")
    local min_age="${PURGE_MIN_AGE_DAYS:-14}"

    ui_banner "Dev Artifact Purge" "Finding stale build artifacts older than ${min_age} days"

    # Determine scan roots
    local -a roots=()
    if [[ ${#MCU_PURGE_PATHS[@]} -gt 0 ]]; then
        roots=("${MCU_PURGE_PATHS[@]}")
    else
        roots=(
            "$HOME/Documents" "$HOME/Downloads" "$HOME/Desktop"
            "$HOME/Developer" "$HOME/dev" "$HOME/Projects" "$HOME/Code"
        )
    fi

    echo -e "${GRAY}Scanning: ${roots[*]}${NC}"
    echo -e "${GRAY}Artifact types: ${artifact_names[*]}${NC}"
    echo ""

    local tmp_list
    tmp_list=$(mktemp)

    local now cutoff
    now=$(date +%s)
    cutoff=$(( now - min_age * 86400 ))

    # Build find expression
    local find_expr=(-name "${artifact_names[0]}")
    local n
    for n in "${artifact_names[@]:1}"; do
        find_expr+=(-o -name "$n")
    done

    local root dir mtime
    for root in "${roots[@]}"; do
        [[ -d "$root" ]] || continue
        while IFS= read -r -d '' dir; do
            mtime=$(stat -f "%m" "$dir" 2>/dev/null || echo 0)
            [[ "$mtime" -lt "$cutoff" ]] && echo "$dir" >> "$tmp_list"
        done < <(find "$root" -type d \( "${find_expr[@]}" \) -prune -print0 2>/dev/null)
    done

    if [[ ! -s "$tmp_list" ]]; then
        echo -e "  ${GRAY}No stale dev artifacts found.${NC}"
        rm -f "$tmp_list"
        return 0
    fi

    sort -u -o "$tmp_list" "$tmp_list"

    local total_kb=0 count=0 size_kb size_h
    echo -e "${BOLD}Candidates (untouched > ${min_age} days):${NC}"
    while IFS= read -r dir; do
        size_kb=$(path_size_kb "$dir" || echo 0); size_kb=${size_kb:-0}
        total_kb=$(( total_kb + size_kb ))
        size_h=$(path_size_h "$dir" || echo "?")
        printf "  %8s  %s\n" "${size_h:-?}" "$dir"
        count=$(( count + 1 ))
    done < "$tmp_list"

    echo ""
    echo -e "  ${GRAY}Total reclaimable: ~$(( total_kb / 1024 ))MB across ${count} artifact dirs${NC}"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo -e "\n  ${CYAN}Dry-run: nothing deleted.${NC}"
        rm -f "$tmp_list"
        return 0
    fi

    if [[ "${AUTO_YES:-0}" -eq 0 ]]; then
        echo ""
        local reply
        read -r -p "Delete all listed artifact dirs? [y/N] " reply
        if [[ ! "$reply" =~ ^[Yy]$ ]]; then
            echo "Aborted, nothing deleted."
            rm -f "$tmp_list"
            return 0
        fi
    fi

    echo ""
    while IFS= read -r dir; do
        rm -rf -- "$dir" && {
            ui_cleaned "$(basename "$dir")" "removed"
            mcu_oplog "purged" "$dir"
        }
    done < "$tmp_list"
    rm -f "$tmp_list"

    echo ""
    echo -e "${GRAY}Done. Re-run your build tool (npm install / cargo build / swift build) before working on affected projects.${NC}"
}
