#!/bin/bash
# lib/clean/orphans.sh — Orphaned app data scanner: finds cache/log/container
#                         remnants of apps no longer installed.
# Source this file; do not execute directly.

MCU_INSTALLED_BUNDLE_IDS=()

# ── Build a set of installed bundle IDs ──────────────────────────────────────
_populate_installed_bundle_ids() {
    MCU_INSTALLED_BUNDLE_IDS=()
    local app bid
    local -a search_dirs=(
        "/Applications"
        "/System/Applications"
        "/System/Applications/Utilities"
        "$HOME/Applications"
    )

    for sdir in "${search_dirs[@]}"; do
        [[ -d "$sdir" ]] || continue
        for app in "$sdir"/*.app "$sdir"/*/*.app; do
            [[ -d "$app" ]] || continue
            bid=$(defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null || true)
            [[ -n "$bid" ]] && MCU_INSTALLED_BUNDLE_IDS+=("$bid")
        done
    done
}

clean_orphaned_app_data() {
    ui_section "Orphaned App Data"

    # Requires access to ~/Library/Caches
    if ! ls "$HOME/Library/Caches" >/dev/null 2>&1; then
        ui_warn "Cannot scan orphaned data — grant Full Disk Access to Terminal"
        return 0
    fi

    _populate_installed_bundle_ids

    if [[ ${#MCU_INSTALLED_BUNDLE_IDS[@]} -eq 0 ]]; then
        ui_skipped "Orphaned app data" "could not read installed app bundle IDs"
        return 0
    fi

    # Helper: check if bundle_id is installed
    _is_installed() {
        local bid="$1"
        local id
        for id in "${MCU_INSTALLED_BUNDLE_IDS[@]}"; do
            [[ "$id" == "$bid" ]] && return 0
        done
        return 1
    }

    local found=0
    local dir base f

    # Scan ~/Library/Caches and ~/Library/Logs for 3rd-party apps (skip com.apple.* to avoid system services)
    for dir in \
        "$HOME/Library/Caches" \
        "$HOME/Library/Logs" \
    ; do
        [[ -d "$dir" ]] || continue
        for f in "$dir"/com.* "$dir"/org.* "$dir"/net.* "$dir"/io.* "$dir"/dev.*; do
            [[ -e "$f" ]] || continue
            base=$(basename "$f")
            
            # Skip Apple internal services - they are handled in clean_apple_services
            [[ "$base" == com.apple.* ]] && continue

            # Strip trailing version/component suffixes for matching
            local bid="${base%%.*[0-9]*}"
            if ! _is_installed "$base" && ! _is_installed "$bid"; then
                safe_remove_path "$f" "Orphaned app cache: ${base}"
                found=1
            fi
        done
    done

    # Scan ~/Library/Containers — check 3rd party containers
    for dir in "$HOME/Library/Containers"/*/; do
        [[ -d "$dir" ]] || continue
        base=$(basename "$dir")
        # Do not remove Apple system containers here
        [[ "$base" == com.apple.* ]] && continue

        if ! _is_installed "$base"; then
            local info="$dir/Container.plist"
            if [[ -f "$info" ]]; then
                local bid
                bid=$(defaults read "$info" MCMMetadataIdentifier 2>/dev/null || echo "$base")
                if ! _is_installed "$bid"; then
                    safe_remove_path "$dir" "Orphaned container: ${base}"
                    found=1
                fi
            fi
        fi
    done

    [[ $found -eq 0 ]] && ui_skipped "Orphaned app data" "none found"
}
