#!/bin/bash
# lib/core/fs.sh — Filesystem helpers: safe_clean, safe_remove, size helpers, path guards.
# Source this file; do not execute directly.

# ── Global tracking ───────────────────────────────────────────────────────────
MCU_TOTAL_FREED_KB=0
MCU_ITEMS_CLEANED=0
MCU_ITEMS_SKIPPED=0

# ── Human-readable size of a path ─────────────────────────────────────────────
path_size_kb() { du -sk "$1" 2>/dev/null | cut -f1; }
path_size_h()  { du -sh "$1" 2>/dev/null | cut -f1; }

# ── Is a path in the whitelist? ───────────────────────────────────────────────
# Returns 0 (true) if the path matches any entry in MCU_WHITELIST array.
is_whitelisted() {
    local p="$1"
    # Never delete maccleanup's own operation log or config directories
    [[ "$p" == *"/Library/Logs/maccleanup"* || "$p" == *"/Library/Logs/maccleanup" ]] && return 0
    [[ "$p" == *"/.config/maccleanup"* || "$p" == *"/.config/maccleanup" ]] && return 0

    local entry
    for entry in "${MCU_WHITELIST[@]+"${MCU_WHITELIST[@]}"}"; do
        # Support glob patterns via case
        # shellcheck disable=SC2254
        case "$p" in
            $entry) return 0 ;;
        esac
        [[ "$p" == "$entry" ]] && return 0
    done
    return 1
}

# ── Label a path for display ──────────────────────────────────────────────────
path_label() {
    case "$1" in
        *"Music Library.musiclibrary"*)          echo "Music app library";;
        *"Movies/TV"*)                            echo "TV app";;
        *GeoServices*)                             echo "Maps/GeoServices";;
        *com.apple.helpd*)                         echo "Help Viewer";;
        *CloudKit*)                                 echo "iCloud/CloudKit";;
        *com.apple.finder*)                        echo "Finder";;
        *wallpaper.agent*)                          echo "Wallpaper";;
        *wallpaper.extension.aerials*)              echo "Aerial Wallpapers";;
        *mediaanalysisd*)                           echo "Media Analysis";;
        *com.apple.geod*)                          echo "Maps (geod)";;
        *AvatarUI.AvatarPickerMemojiPicker*)        echo "Memoji Picker";;
        *com.apple.freeform*)                      echo "Freeform";;
        *com.apple.AppStore*)                       echo "App Store";;
        *AMPArtworkAgent*)                          echo "Music/TV/Podcasts Artwork";;
        *AppleMediaServicesUI*)                     echo "Apple Media Services";;
        *betafish.adblock-mac*)                     echo "AdBlock";;
        *CrashReporter*)                             echo "Crash Reporter";;
        *"Photos/"*Syndication.photoslibrary*)      echo "Photos Syndication Widget";;
        *org.swift.swiftpm*)                        echo "Swift Package Manager";;
        *CocoaPods*)                                 echo "CocoaPods";;
        *com.apple.dt.Xcode*)                       echo "Xcode";;
        *"Application Support/Docker"*)             echo "Docker Desktop";;
        *Developer/CoreSimulator*)                  echo "Xcode iOS Simulator";;
        *Developer/Xcode/DerivedData*)               echo "Xcode DerivedData";;
        *Developer/Xcode/iOS*)                       echo "Xcode iOS DeviceSupport";;
        *Developer/Xcode/watchOS*)                   echo "Xcode watchOS DeviceSupport";;
        *Developer/Xcode/tvOS*)                      echo "Xcode tvOS DeviceSupport";;
        *"Application Support/Claude"*)             echo "Claude Desktop";;
        *"Application Support/Code"*)                echo "VS Code";;
        *"Antigravity IDE"*|*antigravity-ide*)       echo "Antigravity IDE";;
        *"Application Support/Cursor"*)             echo "Cursor";;
        *"Application Support/Windsurf"*)           echo "Windsurf";;
        *"Application Support/Zed"*)                echo "Zed";;
        *"GitHub Desktop"*)                          echo "GitHub Desktop";;
        *"Application Support/Freebuff"*)           echo "Freebuff";;
        *ai.opencode.desktop*)                       echo "opencode";;
        *.gemini*)                                    echo "Gemini CLI";;
        *.codex*)                                     echo "Codex CLI";;
        *.copilot*)                                   echo "GitHub Copilot CLI";;
        *Caches/Adobe*)                              echo "Adobe";;
        *"Application Support/Notion"*)             echo "Notion";;
        *com.microsoft.Powerpoint*)                 echo "Microsoft PowerPoint";;
        *com.microsoft.Excel*)                       echo "Microsoft Excel";;
        *com.microsoft.Word*)                        echo "Microsoft Word";;
        *WhatsApp*)                                   echo "WhatsApp";;
        *OneDriveStandaloneSuite*)                   echo "OneDrive";;
        *com.spotify.client*)                        echo "Spotify";;
        *.anydesk*)                                   echo "AnyDesk";;
        *"Application Support/Slack"*)               echo "Slack";;
        *us.zoom.xos*|*zoom.us*)                     echo "Zoom";;
        *discord*)                                    echo "Discord";;
        *"Google/Chrome"*|*"Google Chrome"*)         echo "Google Chrome";;
        *Google/GoogleUpdater*)                      echo "Google Software Update";;
        *com.apple.Safari*)                          echo "Safari";;
        *HTTPStorages*)                               echo "Safari/WebKit HTTP Storage";;
        *.cache/pip*|*Library/Caches/pip*)           echo "pip (Python)";;
        *.cache/huggingface*)                        echo "Hugging Face";;
        *.cache/yarn*)                                echo "Yarn";;
        *.cache/pnpm*)                                echo "pnpm";;
        *.cache/uv*)                                  echo "uv (Python)";;
        *.cache/poetry*)                              echo "Poetry";;
        *.gradle/caches*)                            echo "Gradle";;
        *.m2/repository*)                            echo "Maven";;
        *go/pkg/mod/cache*)                          echo "Go Modules";;
        *.npm/_npx*|*.npm/_logs*)                    echo "npm";;
        *.cargo/registry/cache*)                     echo "Rust/Cargo";;
        */private/var/log/powermanagement*)          echo "Power Management Logs (sudo)";;
        */private/var/log/DiagnosticMessages*)       echo "Diagnostic Messages (sudo)";;
        */private/var/log/asl*)                      echo "Apple System Log (sudo)";;
        */private/var/log/*.gz|*/private/var/log/*.bz2) echo "System Log Archive (sudo)";;
        */private/var/db/diagnostics*)               echo "System Diagnostics (sudo)";;
        *com.google.Chrome.code_sign_clone*)         echo "Chrome Update Leftover";;
        *DiagnosticReports*)                          echo "Diagnostic Reports";;
        *.zsh_sessions*)                              echo "Zsh Session History";;
        *com.apple.gpuarchiver*|*com.apple.metal*)   echo "Metal/GPU Shader Cache";;
        *"Application Support/"*)
            local rest="${1#*Application Support/}"
            echo "${rest%%/*}";;
        *"Group Containers/"*)
            local rest="${1#*Group Containers/}"
            echo "${rest%%/*}";;
        *"Containers/"*)
            local rest="${1#*Containers/}"
            echo "${rest%%/*}";;
        *) basename "$1";;
    esac
}

# ── Core: empty directory contents ────────────────────────────────────────────
# Usage: safe_clean_dir <path> [label_override]
safe_clean_dir() {
    local p="$1"
    local label="${2:-$(path_label "$p")}"

    [[ -d "$p" ]] || return 0
    is_whitelisted "$p" && { ui_skipped "$label" "whitelisted"; return 0; }

    local size_kb size_h folder_name
    size_kb=$(path_size_kb "$p"); size_kb=${size_kb:-0}
    size_h=$(path_size_h   "$p"); size_h=${size_h:-0B}
    folder_name=$(basename "$p" 2>/dev/null || echo "")

    if [[ -n "${SCAN_COLLECT_FILE:-}" ]]; then
        printf "%s\t%s\t%s\t%s\t%s\t%s\tclean\n" \
            "${CURRENT_CATEGORY:-General}" "$label" "$folder_name" "$size_h" "$size_kb" "$p" >> "$SCAN_COLLECT_FILE"
        MCU_TOTAL_FREED_KB=$(( MCU_TOTAL_FREED_KB + size_kb ))
        MCU_ITEMS_CLEANED=$(( MCU_ITEMS_CLEANED + 1 ))
        return 0
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        ui_dry "$label" "$size_h" "$p"
        MCU_TOTAL_FREED_KB=$(( MCU_TOTAL_FREED_KB + size_kb ))
        MCU_ITEMS_CLEANED=$(( MCU_ITEMS_CLEANED + 1 ))
        return 0
    fi

    find "$p" -mindepth 1 -not -path "*/maccleanup" -not -path "*/maccleanup/*" -exec rm -rf -- {} + 2>/dev/null || true
    if find "$p" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
        ui_skipped "$label" "no permission — grant Full Disk Access to Terminal"
        MCU_ITEMS_SKIPPED=$(( MCU_ITEMS_SKIPPED + 1 ))
    else
        MCU_TOTAL_FREED_KB=$(( MCU_TOTAL_FREED_KB + size_kb ))
        MCU_ITEMS_CLEANED=$(( MCU_ITEMS_CLEANED + 1 ))
        ui_cleaned "$label" "$size_h" "$p"
        mcu_oplog "cleaned" "$p" "$size_h"
    fi
}

# ── Core: remove a path entirely ─────────────────────────────────────────────
# Usage: safe_remove_path <path> [label_override]
safe_remove_path() {
    local p="$1"
    local label="${2:-$(path_label "$p")}"

    { [[ -e "$p" ]] || [[ -L "$p" ]]; } || return 0
    is_whitelisted "$p" && { ui_skipped "$label" "whitelisted"; return 0; }

    local size_kb size_h folder_name
    size_kb=$(path_size_kb "$p"); size_kb=${size_kb:-0}
    size_h=$(path_size_h   "$p"); size_h=${size_h:-0B}
    folder_name=$(basename "$p" 2>/dev/null || echo "")

    if [[ -n "${SCAN_COLLECT_FILE:-}" ]]; then
        printf "%s\t%s\t%s\t%s\t%s\t%s\tremove\n" \
            "${CURRENT_CATEGORY:-General}" "$label" "$folder_name" "$size_h" "$size_kb" "$p" >> "$SCAN_COLLECT_FILE"
        MCU_TOTAL_FREED_KB=$(( MCU_TOTAL_FREED_KB + size_kb ))
        MCU_ITEMS_CLEANED=$(( MCU_ITEMS_CLEANED + 1 ))
        return 0
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        ui_dry "$label" "$size_h" "$p"
        MCU_TOTAL_FREED_KB=$(( MCU_TOTAL_FREED_KB + size_kb ))
        MCU_ITEMS_CLEANED=$(( MCU_ITEMS_CLEANED + 1 ))
        return 0
    fi

    rm -rf -- "$p" 2>/dev/null || true
    if [[ -e "$p" ]] || [[ -L "$p" ]]; then
        ui_skipped "$label" "no permission"
        MCU_ITEMS_SKIPPED=$(( MCU_ITEMS_SKIPPED + 1 ))
    else
        MCU_TOTAL_FREED_KB=$(( MCU_TOTAL_FREED_KB + size_kb ))
        MCU_ITEMS_CLEANED=$(( MCU_ITEMS_CLEANED + 1 ))
        ui_cleaned "$label" "$size_h" "$p"
        mcu_oplog "removed" "$p" "$size_h"
    fi
}

# ── Core: clean only if directory exceeds size threshold ─────────────────────
# Usage: safe_clean_dir_if_large <path> <min_mb> [label_override]
safe_clean_dir_if_large() {
    local p="$1" limit_mb="$2"
    local label="${3:-$(path_label "$p")}"

    [[ -d "$p" ]] || return 0
    is_whitelisted "$p" && { ui_skipped "$label" "whitelisted"; return 0; }

    local size_kb
    size_kb=$(path_size_kb "$p"); size_kb=${size_kb:-0}

    if [[ "$size_kb" -le $(( limit_mb * 1024 )) ]]; then
        [[ -z "${SCAN_COLLECT_FILE:-}" ]] && ui_skipped "$label" "<= ${limit_mb}MB"
        return 0
    fi

    safe_clean_dir "$p" "$label"
}

# ── Keep only the newest immediate subdirectory under a parent ────────────────
keep_latest_subdir() {
    local parent="$1"
    [[ -d "$parent" ]] || return 0
    local latest="" latest_time=0 d t

    for d in "$parent"/*/; do
        [[ -d "$d" ]] || continue
        t=$(stat -f "%B" "$d" 2>/dev/null || stat -f "%m" "$d" 2>/dev/null || echo 0)
        if [[ -n "$t" ]] && [[ "$t" -gt "$latest_time" ]]; then
            latest_time="$t"; latest="$d"
        fi
    done

    for d in "$parent"/*/; do
        [[ -d "$d" ]] || continue
        [[ "$d" != "$latest" ]] && safe_remove_path "$d"
    done
}

# ── Remove older version folders inside a Chrome extension directory ──────────
clean_extension_versions() {
    local ext_dir="$1"
    [[ -d "$ext_dir" ]] || return 0
    local ext_id_dir base
    for ext_id_dir in "$ext_dir"/*/; do
        [[ -d "$ext_id_dir" ]] || continue
        base=$(basename "$ext_id_dir")
        [[ "$base" == "Temp" ]] && continue
        keep_latest_subdir "$ext_id_dir"
    done
}
