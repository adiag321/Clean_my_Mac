#!/bin/bash
# lib/clean/browsers.sh — Chrome (all profiles), Safari, Firefox, Arc, Opera cleanup.
# Source this file; do not execute directly.

clean_browsers() {
    ui_section "Browsers"

    # ── Google Chrome ──────────────────────────────────────────────────────────
    safe_clean_dir "$HOME/Library/Caches/Google/Chrome"                            "Chrome browser cache"
    safe_clean_dir "$HOME/Library/Application Support/Google/Chrome/OptGuideOnDeviceClassifierModel" "Chrome AI classifier model"
    safe_clean_dir "$HOME/Library/Application Support/Google/Chrome/OptGuideOnDeviceModel"           "Chrome on-device AI model"
    safe_clean_dir "$HOME/Library/Application Support/Google/Chrome/optimization_guide_model_store"  "Chrome optimization model store"
    safe_clean_dir "$HOME/Library/Application Support/Google/Chrome/Default/optimization_guide_hint_cache_store" "Chrome optimization hint cache"
    safe_clean_dir "$HOME/Library/Application Support/Google/Chrome/extensions_crx_cache"            "Chrome extension installer cache"
    safe_clean_dir "$HOME/Library/Application Support/Google/Chrome/component_crx_cache"             "Chrome component installer cache"
    safe_clean_dir "$HOME/Library/Application Support/Google/GoogleUpdater"                          "Google Software Update"

    # Chrome Default profile caches
    safe_clean_dir "$HOME/Library/Application Support/Google/Chrome/Default/GPUCache"
    safe_clean_dir "$HOME/Library/Application Support/Google/Chrome/Default/Cache/Cache_Data"
    safe_clean_dir "$HOME/Library/Application Support/Google/Chrome/Default/Service Worker/ScriptCache"
    safe_clean_dir "$HOME/Library/Application Support/Google/Chrome/Default/Service Worker/CacheStorage"

    # All Chrome profiles (Profile 1, Profile 2, …)
    shopt -s nullglob
    local p
    for p in "$HOME/Library/Application Support/Google/Chrome"/Profile*/optimization_guide_hint_cache_store; do
        safe_clean_dir "$p"
    done
    for p in "$HOME/Library/Application Support/Google/Chrome"/*/Cache/Cache_Data; do
        safe_clean_dir "$p"
    done
    for p in "$HOME/Library/Application Support/Google/Chrome"/*/"Service Worker"/ScriptCache; do
        safe_clean_dir "$p"
    done
    for p in "$HOME/Library/Application Support/Google/Chrome"/*/"Service Worker"/CacheStorage; do
        safe_clean_dir "$p"
    done
    for p in "$HOME/Library/Application Support/Google/Chrome"/*/GPUCache; do
        safe_clean_dir "$p"
    done
    shopt -u nullglob

    # Chrome extension version deduplication (keep latest version only)
    local ext_dir
    for ext_dir in "$HOME/Library/Application Support/Google/Chrome"/*/Extensions; do
        clean_extension_versions "$ext_dir"
    done
    keep_latest_subdir "$HOME/Library/Application Support/Google/Chrome/screen_ai"

    # Chrome update leftover folders
    shopt -s nullglob
    for p in /private/var/folders/*/*/*/com.google.Chrome.code_sign_clone; do
        safe_remove_path "$p" "Chrome update leftover"
    done
    shopt -u nullglob

    # ── Safari ────────────────────────────────────────────────────────────────
    safe_clean_dir "$HOME/Library/Containers/com.apple.Safari/Data/Library/Caches" "Safari"
    safe_clean_dir "$HOME/Library/HTTPStorages"                                      "Safari/WebKit HTTP Storage"

    # ── Firefox ───────────────────────────────────────────────────────────────
    shopt -s nullglob
    for p in "$HOME/Library/Caches/Firefox/Profiles/"*/cache2; do
        safe_clean_dir "$p" "Firefox cache"
    done
    shopt -u nullglob
    safe_clean_dir "$HOME/Library/Application Support/Firefox/Crash Reports" "Firefox crash reports"

    # ── Arc Browser ───────────────────────────────────────────────────────────
    safe_clean_dir "$HOME/Library/Application Support/Arc/User Data/Default/Cache/Cache_Data" "Arc browser cache"
    safe_clean_dir "$HOME/Library/Application Support/Arc/User Data/Default/GPUCache"         "Arc GPU cache"

    # ── Opera ─────────────────────────────────────────────────────────────────
    safe_clean_dir "$HOME/Library/Application Support/com.operasoftware.Opera/Cache/Cache_Data" "Opera cache"
}
