#!/bin/bash
# lib/clean/apps.sh — AI/IDE tools, productivity apps, and desktop apps cleanup.
# Source this file; do not execute directly.

clean_ai_ide_apps() {
    ui_section "AI & IDE Apps"

    # Claude Desktop
    for p in \
        "$HOME/Library/Application Support/Claude/vm_bundles" \
        "$HOME/Library/Application Support/Claude/Code Cache" \
        "$HOME/Library/Application Support/Claude/Cache" \
        "$HOME/Library/Application Support/Claude/Cache/Cache_Data" \
        "$HOME/Library/Application Support/Claude/GPUCache" \
        "$HOME/Library/Application Support/Claude/DawnGraphiteCache" \
        "$HOME/Library/Application Support/Claude/DawnWebGPUCache" \
    ; do safe_clean_dir "$p"; done

    # VS Code
    for p in \
        "$HOME/Library/Application Support/Code/Cache/Cache_Data" \
        "$HOME/Library/Application Support/Code/Code Cache" \
        "$HOME/Library/Application Support/Code/DawnGraphiteCache" \
        "$HOME/Library/Application Support/Code/DawnWebGPUCache" \
        "$HOME/Library/Application Support/Code/WebStorage" \
        "$HOME/Library/Application Support/Code/GPUCache" \
        "$HOME/Library/Application Support/Code/Crashpad" \
        "$HOME/Library/Application Support/Code/CachedData" \
        "$HOME/Library/Application Support/Code/logs" \
        "$HOME/Library/Application Support/Code/CachedExtensionVSIXs" \
        "$HOME/Library/Application Support/Code/User/Crashpad" \
        "$HOME/Library/Application Support/Code/User/Service Worker/CacheStorage" \
        "$HOME/Library/Application Support/Code/User/Service Worker/ScriptCache" \
    ; do safe_clean_dir "$p"; done
    safe_clean_dir_if_large "$HOME/Library/Application Support/Code/Local Storage/leveldb" 50 "VS Code Local Storage/leveldb"

    # Antigravity IDE
    for p in \
        "$HOME/Library/Application Support/Antigravity IDE/CachedData" \
        "$HOME/Library/Application Support/Antigravity IDE/GPUCache" \
        "$HOME/Library/Application Support/Antigravity IDE/logs" \
        "$HOME/Library/Application Support/Antigravity IDE/Code Cache" \
        "$HOME/Library/Application Support/Antigravity IDE/DawnGraphiteCache" \
        "$HOME/Library/Application Support/Antigravity IDE/DawnWebGPUCache" \
        "$HOME/Library/Application Support/Antigravity IDE/Cache/Cache_Data" \
    ; do safe_clean_dir "$p"; done

    # Antigravity IDE Jupyter temp
    shopt -s nullglob
    for p in "$HOME/.antigravity-ide/extensions/"*"/temp"; do
        safe_clean_dir "$p" "Antigravity IDE extension temp"
    done
    shopt -u nullglob

    # Cursor
    for p in \
        "$HOME/Library/Application Support/Cursor/CachedData" \
        "$HOME/Library/Application Support/Cursor/GPUCache" \
        "$HOME/Library/Application Support/Cursor/logs" \
        "$HOME/Library/Application Support/Cursor/Code Cache" \
        "$HOME/Library/Application Support/Cursor/Cache/Cache_Data" \
    ; do safe_clean_dir "$p"; done

    # Windsurf
    for p in \
        "$HOME/Library/Application Support/Windsurf/CachedData" \
        "$HOME/Library/Application Support/Windsurf/GPUCache" \
        "$HOME/Library/Application Support/Windsurf/logs" \
        "$HOME/Library/Application Support/Windsurf/Code Cache" \
        "$HOME/Library/Application Support/Windsurf/Cache/Cache_Data" \
    ; do safe_clean_dir "$p"; done

    # Zed
    safe_clean_dir "$HOME/Library/Application Support/Zed/logs"
    safe_clean_dir "$HOME/Library/Application Support/Zed/extensions/.trash" "Zed extension trash"

    # GitHub Desktop
    for p in \
        "$HOME/Library/Application Support/GitHub Desktop/Code Cache" \
        "$HOME/Library/Application Support/GitHub Desktop/GPUCache" \
        "$HOME/Library/Application Support/GitHub Desktop/DawnGraphiteCache" \
        "$HOME/Library/Application Support/GitHub Desktop/DawnWebGPUCache" \
        "$HOME/Library/Application Support/GitHub Desktop/Cache/Cache_Data" \
    ; do safe_clean_dir "$p"; done

    # Freebuff
    for p in \
        "$HOME/Library/Application Support/Freebuff/Code Cache" \
        "$HOME/Library/Application Support/Freebuff/GPUCache" \
        "$HOME/Library/Application Support/Freebuff/DawnGraphiteCache" \
        "$HOME/Library/Application Support/Freebuff/DawnWebGPUCache" \
        "$HOME/Library/Application Support/Freebuff/Cache" \
    ; do safe_clean_dir "$p"; done

    # opencode
    for p in \
        "$HOME/Library/Application Support/ai.opencode.desktop/Code Cache" \
        "$HOME/Library/Application Support/ai.opencode.desktop/GPUCache" \
        "$HOME/Library/Application Support/ai.opencode.desktop/DawnGraphiteCache" \
        "$HOME/Library/Application Support/ai.opencode.desktop/DawnWebGPUCache" \
        "$HOME/Library/Application Support/ai.opencode.desktop/Cache/Cache_Data" \
        "$HOME/.local/share/opencode/log" \
    ; do safe_clean_dir "$p"; done

    # AI CLI tools
    safe_clean_dir "$HOME/.gemini/tmp"         "Gemini CLI"
    safe_clean_dir "$HOME/.codex/cache"        "Codex CLI"
    safe_clean_dir "$HOME/.copilot/logs"       "GitHub Copilot CLI"
}

clean_productivity_apps() {
    ui_section "Productivity Apps"

    # Adobe
    safe_clean_dir "$HOME/Library/Caches/Adobe"

    # Notion
    for p in \
        "$HOME/Library/Application Support/Notion/Partitions/notion/Cache/Cache_Data" \
        "$HOME/Library/Application Support/Notion/Partitions/notion/Service Worker/CacheStorage" \
        "$HOME/Library/Application Support/Notion/Partitions/notion/Service Worker/ScriptCache" \
        "$HOME/Library/Application Support/Notion/Partitions/notion/Code Cache" \
        "$HOME/Library/Application Support/Notion/Code Cache" \
        "$HOME/Library/Application Support/Notion/GPUCache" \
        "$HOME/Library/Application Support/Notion/DawnGraphiteCache" \
        "$HOME/Library/Application Support/Notion/DawnWebGPUCache" \
        "$HOME/Library/Application Support/Notion/Cache/Cache_Data" \
    ; do safe_clean_dir "$p"; done

    # Slack
    for p in \
        "$HOME/Library/Application Support/Slack/Cache/Cache_Data" \
        "$HOME/Library/Application Support/Slack/Code Cache" \
        "$HOME/Library/Application Support/Slack/GPUCache" \
    ; do safe_clean_dir "$p"; done

    # Discord
    for p in \
        "$HOME/Library/Application Support/discord/Cache/Cache_Data" \
        "$HOME/Library/Application Support/discord/Code Cache" \
        "$HOME/Library/Application Support/discord/GPUCache" \
    ; do safe_clean_dir "$p"; done

    # Zoom
    safe_clean_dir "$HOME/Library/Caches/us.zoom.xos"       "Zoom"
    safe_clean_dir "$HOME/Library/Logs/zoom.us"              "Zoom logs"

    # Spotify
    safe_clean_dir "$HOME/Library/Containers/com.spotify.client/Data/Library/Caches"

    # AnyDesk
    safe_clean_dir "$HOME/.anydesk/thumbnails"

    # Adblock extensions
    safe_clean_dir "$HOME/Library/Containers/com.betafish.adblock-mac/Data/Library/Caches"
    safe_clean_dir "$HOME/Library/Containers/com.betafish.adblock-mac.SafariContentBlocker/Data/Library/Caches"
    safe_clean_dir "$HOME/Library/Group Containers/group.com.betafish.adblock-mac/Library/Caches/logs"
}

clean_microsoft_office() {
    ui_section "Microsoft Office"

    for p in \
        "$HOME/Library/Containers/com.microsoft.Powerpoint/Data/Library/Logs" \
        "$HOME/Library/Containers/com.microsoft.Powerpoint/Data/Library/Caches" \
        "$HOME/Library/Containers/com.microsoft.Excel/Data/Library/Logs" \
        "$HOME/Library/Containers/com.microsoft.Excel/Data/Library/Caches" \
        "$HOME/Library/Containers/com.microsoft.Excel/Data/tmp" \
        "$HOME/Library/Containers/com.microsoft.Word/Data/Library/Logs" \
        "$HOME/Library/Containers/com.microsoft.Word/Data/Library/Caches" \
        "$HOME/Library/Containers/com.microsoft.Word/Data/tmp" \
    ; do safe_clean_dir "$p"; done
}

clean_messaging_apps() {
    ui_section "Messaging Apps"

    # WhatsApp — media only if large (>500MB), regular caches always
    for p in \
        "$HOME/Library/Containers/net.whatsapp.WhatsApp/Data/Library/Caches" \
        "$HOME/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/Logs" \
        "$HOME/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/Logs/WhatsApp_2" \
        "$HOME/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/Library/Caches" \
        "$HOME/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/statusDB" \
        "$HOME/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/stickers" \
    ; do safe_clean_dir "$p"; done
    safe_clean_dir_if_large \
        "$HOME/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/Message/Media" \
        500 "WhatsApp Message/Media (>500MB)"

    # OneDrive
    safe_clean_dir "$HOME/Library/Group Containers/UBF8T346G9.OneDriveStandaloneSuite/FileProviderLogs" "OneDrive logs"
}

clean_ghost_apps() {
    ui_section "Ghost App Leftovers"

    # Apps whose data should be removed if the .app bundle is gone
    local -a ghost_candidates=(
        "Firefox"
        "Opera"
        "Windsurf"
        "Freebuff"
        "Zed"
        "Slack"
        "Discord"
        "Zoom"
    )

    local app found_any=false
    for app in "${ghost_candidates[@]}"; do
        local ghost_path="$HOME/Library/Application Support/${app}"
        if [[ ! -d "/Applications/${app}.app" ]] && [[ -d "$ghost_path" ]]; then
            found_any=true
            safe_remove_path "$ghost_path" "Ghost app leftover: ${app}"
        fi
    done
    $found_any || ui_skipped "Ghost app leftovers" "none found"
}
