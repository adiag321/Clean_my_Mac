#!/bin/bash
# lib/clean/user.sh — User essentials: ~/Library/Caches, Logs, Trash, ~/.cache,
#                     Apple system services (GeoServices, helpd, CloudKit, etc.)
# Source this file; do not execute directly.

clean_user_essentials() {
    ui_section "User Essentials"

    # Core user cache and log roots
    safe_clean_dir "$HOME/Library/Caches"          "User app cache"
    safe_clean_dir "$HOME/Library/Logs"            "User app logs"
    safe_clean_dir "$HOME/.cache"                  "Generic Unix cache (~/.cache)"
    safe_clean_dir "$HOME/.zsh_sessions"           "Zsh session history"
    safe_clean_dir "$HOME/Library/Logs/DiagnosticReports" "Diagnostic Reports"
    safe_clean_dir "$HOME/Library/Application Support/CrashReporter" "Crash Reporter"
}

clean_apple_services() {
    ui_section "Apple System Services"

    # Apple service caches
    safe_clean_dir "$HOME/Library/Caches/GeoServices"            "Maps/GeoServices"
    safe_clean_dir "$HOME/Library/Caches/com.apple.helpd"        "Help Viewer"
    safe_clean_dir "$HOME/Library/Caches/CloudKit"               "iCloud/CloudKit"
    safe_clean_dir "$HOME/Library/Caches/com.apple.finder"       "Finder"
    safe_clean_dir "$HOME/Library/HTTPStorages"                   "Safari/WebKit HTTP Storage"

    # Container-sandboxed Apple services
    safe_clean_dir "$HOME/Library/Containers/com.apple.wallpaper.agent/Data/Library/Caches"
    safe_clean_dir "$HOME/Library/Containers/com.apple.wallpaper.extension.aerials/Data/tmp"
    safe_clean_dir "$HOME/Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches"
    safe_remove_path "$HOME/Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches/com.apple.mediaanalysisd"
    safe_clean_dir "$HOME/Library/Containers/com.apple.geod/Data/Library/Caches"
    safe_remove_path "$HOME/Library/Containers/com.apple.geod/Data/tmp"
    safe_clean_dir "$HOME/Library/Containers/com.apple.AvatarUI.AvatarPickerMemojiPicker/Data/Library/Caches"
    safe_clean_dir "$HOME/Library/Containers/com.apple.freeform/Data/Library/Caches"
    safe_clean_dir "$HOME/Library/Containers/com.apple.AppStore/Data/Library/Caches"
    safe_clean_dir "$HOME/Library/Containers/com.apple.AMPArtworkAgent/Data/Documents/artwork" "Music/TV/Podcasts Artwork Cache"
    safe_clean_dir "$HOME/Library/Containers/com.apple.AMPArtworkAgent/Data/Library/Caches"
    safe_clean_dir "$HOME/Library/Containers/com.apple.AppleMediaServicesUI.UtilityExtension/Data/tmp"

    # System preferences cache
    safe_remove_path "$HOME/Library/Group Containers/com.apple.systempreferences.cache/com.apple.systemsettings.usercache" "System Settings cache"

    # Photos Syndication widget cache (glob scan)
    local p
    while IFS= read -r -d '' p; do
        safe_remove_path "$p" "Photos Syndication Widget"
    done < <(find "$HOME/Library/Photos" -maxdepth 4 -iname "Syndication.photoslibrary" -print0 2>/dev/null)
}

clean_trash() {
    ui_section "Trash"
    if is_whitelisted "$HOME/.Trash"; then
        ui_skipped "Trash" "whitelisted"
        return 0
    fi

    if [[ ! -d "$HOME/.Trash" ]]; then
        ui_skipped "Trash" "not found"
        return 0
    fi

    local count
    count=$(find "$HOME/.Trash" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
    local size_h
    size_h=$(path_size_h "$HOME/.Trash")

    if [[ "$count" -eq 0 ]]; then
        ui_skipped "Trash" "already empty"
        return 0
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        ui_dry "Trash" "${size_h:-?}" "$HOME/.Trash (${count} items)"
        return 0
    fi

    find "$HOME/.Trash" -mindepth 1 -exec rm -rf -- {} + 2>/dev/null || true
    local size_kb
    size_kb=$(path_size_kb "$HOME/.Trash" 2>/dev/null || echo 0)
    MCU_TOTAL_FREED_KB=$(( MCU_TOTAL_FREED_KB + size_kb ))
    MCU_ITEMS_CLEANED=$(( MCU_ITEMS_CLEANED + 1 ))
    ui_cleaned "Trash" "${size_h:-?} (${count} items)"
    mcu_oplog "emptied" "$HOME/.Trash" "${size_h:-?}"
}

# Metal/GPU shader caches — only remove if stale (>1 day since last use)
clean_gpu_caches() {
    ui_section "Metal/GPU Shader Caches (stale)"
    local cache_dir found=0
    while IFS= read -r -d '' cache_dir; do
        # Check if any file was modified in the last day
        local recent
        recent=$(find "$cache_dir" -type f -mtime -1 -print -quit 2>/dev/null)
        if [[ -z "$recent" ]]; then
            safe_clean_dir "$cache_dir" "Metal/GPU shader cache (stale)"
            found=1
        fi
    done < <(find /private/var/folders -maxdepth 4 \
        \( -name "com.apple.gpuarchiver" -o -name "com.apple.metal" -o -name "com.apple.metalfe" \) \
        -type d -print0 2>/dev/null)
    [[ $found -eq 0 ]] && ui_skipped "Metal/GPU caches" "none stale"
}
