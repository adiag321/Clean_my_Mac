#!/bin/bash
# lib/installer/installer.sh — Stale installer file cleanup: .dmg, .pkg, .mpkg, .iso, .xip
# Source this file; do not execute directly.

run_installer_cleanup() {
    local min_age="${INSTALLER_MIN_AGE_DAYS:-3}"

    local -a locations=(
        "$HOME/Downloads"
        "$HOME/Desktop"
        "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Downloads"
        "$HOME/Library/Containers/com.apple.mail/Data/Library/Mail Downloads"
    )

    if command -v brew >/dev/null 2>&1; then
        local brew_cache
        brew_cache=$(brew --cache 2>/dev/null)
        [[ -n "$brew_cache" ]] && locations+=("$brew_cache")
    fi

    ui_banner "Stale Installer Cleanup" "Extensions: .dmg .pkg .mpkg .iso .xip  |  Older than: ${min_age} days"

    local tmp_list
    tmp_list=$(mktemp)

    local loc f
    for loc in "${locations[@]}"; do
        [[ -d "$loc" ]] || continue
        while IFS= read -r -d '' f; do
            echo "$f" >> "$tmp_list"
        done < <(find "$loc" -maxdepth 3 -type f \
            \( -iname "*.dmg" -o -iname "*.pkg" -o -iname "*.mpkg" -o -iname "*.iso" -o -iname "*.xip" \) \
            -mtime +"$min_age" -print0 2>/dev/null)
    done

    if [[ ! -s "$tmp_list" ]]; then
        echo -e "  ${GRAY}No stale installers found.${NC}"
        rm -f "$tmp_list"
        return 0
    fi

    sort -u -o "$tmp_list" "$tmp_list"

    local total_kb=0 count=0 size_kb size_h
    echo -e "${BOLD}Candidates:${NC}"
    while IFS= read -r f; do
        size_kb=$(path_size_kb "$f" || echo 0); size_kb=${size_kb:-0}
        total_kb=$(( total_kb + size_kb ))
        size_h=$(path_size_h "$f" || echo "?")
        printf "  %8s  %s\n" "${size_h:-?}" "$f"
        count=$(( count + 1 ))
    done < "$tmp_list"

    echo ""
    echo -e "  ${GRAY}Total reclaimable: ~$(( total_kb / 1024 ))MB across ${count} files${NC}"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo -e "\n  ${CYAN}Dry-run: nothing deleted.${NC}"
        rm -f "$tmp_list"
        return 0
    fi

    if [[ "${AUTO_YES:-0}" -eq 0 ]]; then
        echo ""
        local reply
        read -r -p "Delete all listed installer files? [y/N] " reply
        if [[ ! "$reply" =~ ^[Yy]$ ]]; then
            echo "Aborted, nothing deleted."
            rm -f "$tmp_list"
            return 0
        fi
    fi

    echo ""
    while IFS= read -r f; do
        rm -rf -- "$f" && {
            ui_cleaned "$(basename "$f")" "removed"
            mcu_oplog "removed" "$f"
        }
    done < "$tmp_list"
    rm -f "$tmp_list"
    echo ""
    echo -e "${GRAY}Done.${NC}"
}
