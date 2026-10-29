#!/bin/bash
# lib/analyze/analyze.sh — Interactive disk usage explorer (TUI).
#                           Navigate, sort, and delete large files/directories.
# Source this file; do not execute directly.

run_analyze() {
    local target_path="${1:-$HOME}"
    local threshold_mb="${ANALYZE_THRESHOLD_MB:-100}"

    # Expand ~ if needed
    target_path="${target_path/#\~/$HOME}"

    if [[ ! -d "$target_path" ]]; then
        echo -e "${RED}Path not found: ${target_path}${NC}"
        return 1
    fi

    ui_banner "Disk Analyzer" "${target_path}"

    echo -e "${GRAY}Scanning... (this may take a moment for large directories)${NC}"

    # Build sorted list of items with sizes
    local tmp_list
    tmp_list=$(mktemp)

    # Measure immediate children of the target path
    local item sz_kb
    for item in "$target_path"/.[!.]* "$target_path"/*; do
        [[ -e "$item" ]] || continue
        sz_kb=$(du -sk "$item" 2>/dev/null | cut -f1)
        [[ -z "$sz_kb" ]] && continue
        printf '%s\t%s\n' "$sz_kb" "$item"
    done | sort -rn > "$tmp_list"

    if [[ ! -s "$tmp_list" ]]; then
        echo -e "${GRAY}No items found in ${target_path}${NC}"
        rm -f "$tmp_list"
        return 0
    fi

    # Total size
    local total_kb
    total_kb=$(du -sk "$target_path" 2>/dev/null | cut -f1 || echo 0)
    local total_h
    total_h=$(du -sh "$target_path" 2>/dev/null | cut -f1 || echo "?")

    echo ""
    echo -e "${BOLD}$(printf '%.0s─' {1..70})${NC}"
    printf "  %-45s  %10s  %s\n" "PATH" "SIZE" "TYPE"
    echo -e "${BOLD}$(printf '%.0s─' {1..70})${NC}"

    local rank=1
    while IFS=$'\t' read -r sz_kb item_path; do
        local sz_h type_icon
        sz_h=$(du -sh "$item_path" 2>/dev/null | cut -f1 || echo "?")

        if [[ -d "$item_path" ]]; then
            type_icon="📁"
        else
            type_icon="📄"
        fi

        local item_name
        item_name=$(basename "$item_path")
        local pct=0
        [[ "$total_kb" -gt 0 ]] && pct=$(( sz_kb * 100 / total_kb ))

        # Color large items
        local color="$NC"
        [[ "$sz_kb" -gt $(( threshold_mb * 1024 )) ]] && color="$YELLOW"
        [[ "$sz_kb" -gt $(( threshold_mb * 10 * 1024 )) ]] && color="$RED"

        printf "  ${color}%-2s %-43s  %10s  %s (%s%%)${NC}\n" \
            "$rank)" "$item_name" "${sz_h:-?}" "$type_icon" "$pct"

        rank=$(( rank + 1 ))
        [[ $rank -gt 30 ]] && break   # Cap at 30 items for readability
    done < "$tmp_list"

    echo -e "${BOLD}$(printf '%.0s─' {1..70})${NC}"
    echo -e "  Total: ${BOLD}${total_h}${NC}  in  ${GRAY}${target_path}${NC}"
    echo ""

    # Large files spotlight
    echo -e "${BOLD}Large Files (> ${threshold_mb}MB):${NC}"
    local found_large=false
    find "$target_path" -maxdepth 3 -type f -size +"${threshold_mb}M" \
        -not -path "*/\.*" 2>/dev/null | \
    while IFS= read -r f; do
        local fh
        fh=$(du -sh "$f" 2>/dev/null | cut -f1)
        printf "  ${YELLOW}%8s${NC}  %s\n" "${fh:-?}" "$f"
        found_large=true
    done

    $found_large || echo -e "  ${GRAY}None found above ${threshold_mb}MB threshold.${NC}"
    echo ""

    # Interactive drill-down prompt
    echo -e "${GRAY}Enter a number to drill into a directory, 'd <N>' to delete, or press Enter to exit:${NC}"
    local reply
    read -r reply

    if [[ "$reply" =~ ^[0-9]+$ ]]; then
        local target_rank="$reply"
        local drill_path
        drill_path=$(sed -n "${target_rank}p" "$tmp_list" | cut -f2)
        rm -f "$tmp_list"
        if [[ -d "$drill_path" ]]; then
            run_analyze "$drill_path"
        else
            echo -e "${GRAY}${drill_path} is a file, not a directory.${NC}"
        fi
        return 0
    elif [[ "$reply" =~ ^d[[:space:]]+([0-9]+)$ ]]; then
        local del_rank="${BASH_REMATCH[1]}"
        local del_path
        del_path=$(sed -n "${del_rank}p" "$tmp_list" | cut -f2)
        rm -f "$tmp_list"
        if [[ -z "$del_path" ]]; then
            echo "Invalid selection."
            return 1
        fi
        echo -e "${YELLOW}About to delete: ${del_path}${NC}"
        local confirm
        read -r -p "Send to Trash? [y/N] " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            mv -f -- "$del_path" "$HOME/.Trash/" 2>/dev/null && \
                echo -e "${GREEN}${ICON_OK} Moved to Trash: ${del_path}${NC}" || \
                echo -e "${RED}Failed to move to Trash.${NC}"
            mcu_oplog "analyze-deleted" "$del_path"
        else
            echo "Cancelled."
        fi
        return 0
    fi

    rm -f "$tmp_list"
}
