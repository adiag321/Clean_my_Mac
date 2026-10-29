#!/bin/bash
# lib/slim/slim.sh — Universal binary slimmer: removes Intel x86_64 slices
#                    from universal apps on Apple Silicon Macs.
# Source this file; do not execute directly.

run_slim() {
    ui_banner "Universal Binary Slim" "Remove Intel x86_64 slices from apps on Apple Silicon"

    # Only valid on Apple Silicon
    local arch
    arch=$(uname -m)
    if [[ "$arch" != "arm64" ]]; then
        echo -e "${YELLOW}${ICON_WARN} slim only works on Apple Silicon Macs (this Mac is: ${arch})${NC}"
        return 1
    fi

    local -a scan_paths=("/Applications" "$HOME/Applications")
    local app found=0 total_saved_kb=0

    for scan_dir in "${scan_paths[@]}"; do
        [[ -d "$scan_dir" ]] || continue

        for app in "$scan_dir"/*.app; do
            [[ -d "$app" ]] || continue

            # Find universal binaries inside the app bundle
            local binary
            binary="$app/Contents/MacOS/$(defaults read "$app/Contents/Info" CFBundleExecutable 2>/dev/null || basename "$app" .app)"

            [[ -f "$binary" ]] || continue

            # Check if it's a universal binary (fat)
            if ! file "$binary" 2>/dev/null | grep -q "universal binary"; then
                continue
            fi

            found=1
            local before_kb after_kb saved_kb
            before_kb=$(path_size_kb "$binary" || echo 0); before_kb=${before_kb:-0}

            if [[ "${DRY_RUN:-false}" == "true" ]]; then
                local before_h
                before_h=$(path_size_h "$binary" || echo "?")
                ui_dry "$(basename "$app" .app)" "${before_h}" "$binary"
            else
                # Create a temp copy and thin to arm64
                local tmp_bin="${binary}.arm64.tmp"
                if lipo -remove x86_64 "$binary" -output "$tmp_bin" 2>/dev/null; then
                    mv -f "$tmp_bin" "$binary"
                    after_kb=$(path_size_kb "$binary" || echo 0); after_kb=${after_kb:-0}
                    saved_kb=$(( before_kb - after_kb ))
                    total_saved_kb=$(( total_saved_kb + saved_kb ))
                    ui_cleaned "$(basename "$app" .app)" "saved ~$(( saved_kb / 1024 ))MB"
                    mcu_oplog "slimmed" "$binary" "~$(( saved_kb / 1024 ))MB"
                else
                    rm -f "$tmp_bin" 2>/dev/null || true
                    ui_skipped "$(basename "$app" .app)" "lipo failed (may be code-signed)"
                fi
            fi
        done
    done

    if [[ $found -eq 0 ]]; then
        echo -e "  ${GRAY}No universal binaries found — apps may already be arm64-only.${NC}"
    else
        echo ""
        echo -e "  ${GRAY}Total saved: ~$(( total_saved_kb / 1024 ))MB${NC}"
    fi
}
