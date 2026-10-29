#!/bin/bash
# lib/uninstall/uninstall.sh — Smart app uninstaller with Trash routing,
#                               bundle ID lookup, and leftover scan.
# Source this file; do not execute directly.

# Escape a string for safe embedding in a JSON string value
_json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
}

# List every installed app as JSON: name, bundle_id, source, uninstall_name, path, size (KB)
run_uninstall_list_apps() {
    local first=true
    printf '['
    shopt -s nullglob
    local dir app
    for dir in "/Applications" "$HOME/Applications"; do
        for app in "$dir"/*.app; do
            local name bundle_id size_kb source
            name=$(basename "$app" .app)
            bundle_id=$(defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null || echo "")
            size_kb=$(path_size_kb "$app" 2>/dev/null || echo 0)
            [[ "$dir" == "$HOME/Applications" ]] && source="user" || source="system"

            [[ "$first" == "true" ]] && first=false || printf ','
            printf '{"name":"%s","bundle_id":"%s","source":"%s","uninstall_name":"%s","path":"%s","size_kb":%s}' \
                "$(_json_escape "$name")" "$(_json_escape "$bundle_id")" "$source" "$(_json_escape "$name")" "$(_json_escape "$app")" "${size_kb:-0}"
        done
    done
    shopt -u nullglob
    printf ']\n'
}

run_uninstall_app() {
    local app_name="$1"
    local app_path=""
    local candidate

    for candidate in "/Applications/${app_name}.app" "$HOME/Applications/${app_name}.app"; do
        [[ -d "$candidate" ]] && { app_path="$candidate"; break; }
    done

    if [[ -z "$app_path" ]]; then
        echo -e "${RED}Could not find: /Applications/${app_name}.app or ~/Applications/${app_name}.app${NC}"
        echo "Pass the exact name without \".app\", e.g. \"Google Chrome\""
        return 1
    fi

    local bundle_id
    bundle_id=$(defaults read "$app_path/Contents/Info" CFBundleIdentifier 2>/dev/null || echo "")

    ui_banner "App Uninstaller" "${app_path}"
    echo -e "  ${GRAY}Bundle ID: ${bundle_id:-<unknown>}${NC}"
    echo ""

    local tmp_list tmp_data_list
    tmp_list=$(mktemp)
    tmp_data_list=$(mktemp)

    # Cache-like leftovers are always safe to remove. Application Support /
    # Containers / Group Containers can hold personal data (documents, saved
    # state, licenses), so they're only auto-selected with --with-data.
    _add_if_exists() {
        [[ -e "$1" ]] && echo "$1" >> "$tmp_list"
    }
    _add_data_if_exists() {
        [[ -e "$1" ]] && echo "$1" >> "$tmp_data_list"
    }

    # Standard leftovers by app name
    _add_data_if_exists "$HOME/Library/Application Support/${app_name}"
    _add_if_exists "$HOME/Library/Caches/${app_name}"
    _add_if_exists "$HOME/Library/Logs/${app_name}"
    _add_if_exists "$HOME/Library/WebKit/${app_name}"

    if [[ -n "$bundle_id" ]]; then
        _add_data_if_exists "$HOME/Library/Containers/${bundle_id}"

        shopt -s nullglob
        local f
        for f in "$HOME/Library/Caches/${bundle_id}"*;                     do _add_if_exists "$f"; done
        for f in "$HOME/Library/Preferences/${bundle_id}"*.plist;           do _add_if_exists "$f"; done
        for f in "$HOME/Library/Saved Application State/${bundle_id}"*.savedState; do _add_if_exists "$f"; done
        for f in "$HOME/Library/HTTPStorages/${bundle_id}"*;                do _add_if_exists "$f"; done
        for f in "$HOME/Library/LaunchAgents/${bundle_id}"*.plist;         do _add_if_exists "$f"; done
        shopt -u nullglob

        # Group Containers by domain suffix — may hold shared app-group data
        local domain_tail="${bundle_id#*.}"
        if [[ -n "$domain_tail" ]] && [[ -d "$HOME/Library/Group Containers" ]]; then
            local d
            while IFS= read -r -d '' d; do
                echo "$d" >> "$tmp_data_list"
            done < <(find "$HOME/Library/Group Containers" -maxdepth 1 -iname "*${domain_tail}*" -print0 2>/dev/null)
        fi
    fi

    local with_data="${UNINSTALL_WITH_DATA:-false}"

    echo -e "${BOLD}Found leftovers:${NC}"
    if [[ -s "$tmp_list" ]]; then
        sort -u -o "$tmp_list" "$tmp_list"
        local p size_h total_kb=0
        while IFS= read -r p; do
            local sz_kb sz_h
            sz_kb=$(path_size_kb "$p" || echo 0); sz_kb=${sz_kb:-0}
            sz_h=$(path_size_h "$p" || echo "?")
            total_kb=$(( total_kb + sz_kb ))
            printf "  %8s  %s\n" "${sz_h:-?}" "$p"
        done < "$tmp_list"
        echo ""
        echo -e "  ${GRAY}Total reclaimable: ~$(( total_kb / 1024 ))MB${NC}"
    else
        echo "  (none found besides the app bundle itself)"
    fi

    if [[ -s "$tmp_data_list" ]]; then
        sort -u -o "$tmp_data_list" "$tmp_data_list"
        echo ""
        if [[ "$with_data" == "true" ]]; then
            echo -e "${BOLD}Personal data (--with-data, will be removed):${NC}"
        else
            echo -e "${BOLD}Personal data (kept by default, pass --with-data to remove):${NC}"
        fi
        local p sz_h
        while IFS= read -r p; do
            sz_h=$(path_size_h "$p" || echo "?")
            printf "  %8s  %s\n" "${sz_h:-?}" "$p"
        done < "$tmp_data_list"
    fi

    if [[ "$with_data" == "true" ]]; then
        cat "$tmp_data_list" >> "$tmp_list"
    fi

    echo ""
    if [[ -n "$bundle_id" ]]; then
        echo -e "${GRAY}Note: system-wide launch daemons not checked automatically."
        echo "      To check: grep -rl \"${bundle_id}\" /Library/LaunchAgents /Library/LaunchDaemons 2>/dev/null${NC}"
    fi
    echo -e "${GRAY}Note: another copy of this app sharing the same bundle ID would also lose shared data.${NC}"

    if [[ "${LIST_ONLY:-0}" -eq 1 ]] || [[ "${DRY_RUN:-false}" == "true" ]]; then
        rm -f "$tmp_list" "$tmp_data_list"
        return 0
    fi

    if [[ "${AUTO_YES:-0}" -eq 0 ]]; then
        echo ""
        local reply
        read -r -p "Remove the app and everything listed above? [y/N] " reply
        if [[ ! "$reply" =~ ^[Yy]$ ]]; then
            echo "Aborted, nothing removed."
            rm -f "$tmp_list" "$tmp_data_list"
            return 0
        fi
    fi

    echo ""

    # Route to Trash or delete permanently
    local use_trash="${UNINSTALL_TRASH:-true}"
    local trash_dir="$HOME/.Trash"

    _delete_path() {
        local target="$1"
        if [[ "$use_trash" == "true" ]]; then
            mv -f -- "$target" "$trash_dir/" 2>/dev/null && \
                echo -e "  ${GREEN}${ICON_OK}${NC} Moved to Trash: $target" || \
                echo -e "  ${YELLOW}${ICON_WARN}${NC} Could not move to Trash: $target"
        else
            rm -rf -- "$target" 2>/dev/null && \
                echo -e "  ${GREEN}${ICON_OK}${NC} Removed: $target" || \
                echo -e "  ${YELLOW}${ICON_WARN}${NC} Could not remove: $target"
        fi
        mcu_oplog "uninstalled" "$target"
    }

    _delete_path "$app_path"
    local p
    while IFS= read -r p; do
        _delete_path "$p"
    done < "$tmp_list"
    rm -f "$tmp_list" "$tmp_data_list"

    echo ""
    if [[ "$use_trash" == "true" ]]; then
        echo -e "${GRAY}Items sent to Trash. Empty Trash to reclaim disk space.${NC}"
    fi
    echo -e "${GRAY}Done. If ${app_name} left a menu bar helper running, log out/in to fully clear it.${NC}"
}
