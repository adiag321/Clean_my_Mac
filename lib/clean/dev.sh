#!/bin/bash
# lib/clean/dev.sh — Developer tools: Xcode, CoreSimulator, Swift, CocoaPods, Docker.
# Source this file; do not execute directly.

clean_xcode() {
    ui_section "Xcode & iOS Dev Tools"

    # Check if Xcode or build tooling is running
    if pgrep -xq "Xcode" 2>/dev/null || pgrep -xq "xcodebuild" 2>/dev/null; then
        ui_warn "Xcode is running — DerivedData and DeviceSupport skipped to avoid build corruption"
        ui_warn "Quit Xcode and re-run to clean Xcode artifacts"
    else
        safe_clean_dir "$HOME/Library/Developer/Xcode/DerivedData"
        safe_clean_dir "$HOME/Library/Developer/Xcode/iOS DeviceSupport"
        safe_clean_dir "$HOME/Library/Developer/Xcode/watchOS DeviceSupport"
        safe_clean_dir "$HOME/Library/Developer/Xcode/tvOS DeviceSupport"
        safe_clean_dir "$HOME/Library/Developer/Xcode/visionOS DeviceSupport"
    fi

    # CoreSimulator — check if Simulator is running
    if pgrep -xq "Simulator" 2>/dev/null || pgrep -xq "xctest" 2>/dev/null; then
        ui_warn "Simulator is running — CoreSimulator cache skipped"
    else
        safe_clean_dir "$HOME/Library/Developer/CoreSimulator"

        # Remove unavailable simulator devices
        if command -v xcrun >/dev/null 2>&1; then
            if [[ "${DRY_RUN:-false}" != "true" ]]; then
                if xcrun simctl delete unavailable 2>/dev/null; then
                    ui_cleaned "Unavailable simulator devices" "removed"
                fi
            else
                ui_dry "Unavailable simulator devices" "?" "xcrun simctl delete unavailable"
            fi
        fi
    fi

    # Xcode caches (safe regardless of Xcode running state)
    safe_clean_dir "$HOME/Library/Caches/com.apple.dt.Xcode"
    safe_clean_dir "$HOME/Library/Caches/org.swift.swiftpm"   "Swift Package Manager"
    safe_clean_dir "$HOME/Library/Caches/CocoaPods"            "CocoaPods"
    safe_clean_dir "$HOME/Library/Developer/Xcode/UserData/Previews" "SwiftUI Previews"
    safe_clean_dir "$HOME/.cocoapods/repos"                    "CocoaPods spec repos"
    safe_clean_dir "$HOME/Library/Caches/org.carthage.CarthageKit" "Carthage"
}

clean_jetbrains() {
    ui_section "JetBrains IDEs"

    if pgrep -iq "idea\|pycharm\|webstorm\|goland\|rubymine\|clion\|rider\|android studio" 2>/dev/null; then
        ui_warn "A JetBrains IDE is running — caches skipped to avoid corrupting open indexes"
        return 0
    fi

    shopt -s nullglob
    local d
    for d in "$HOME/Library/Caches/JetBrains"/*/; do
        safe_clean_dir "${d%/}" "$(basename "$d")"
    done
    shopt -u nullglob
}

clean_steam() {
    ui_section "Steam"

    if pgrep -xq "steam_osx" 2>/dev/null; then
        ui_warn "Steam is running — cache skipped"
        return 0
    fi

    safe_clean_dir "$HOME/Library/Application Support/Steam/appcache" "Steam app cache"
    safe_clean_dir "$HOME/Library/Application Support/Steam/depotcache" "Steam depot cache"
}

clean_docker() {
    ui_section "Docker"

    safe_clean_dir "$HOME/Library/Application Support/Docker"

    # Docker builder cache (if docker CLI available)
    if command -v docker >/dev/null 2>&1 && [[ "${DRY_RUN:-false}" != "true" ]]; then
        if docker system info >/dev/null 2>&1; then
            local before after
            before=$(docker system df --format '{{.Size}}' 2>/dev/null | head -1 || echo "?")
            docker builder prune -f >/dev/null 2>&1 || true
            ui_cleaned "Docker builder cache" "${before}"
            mcu_oplog "cleaned" "docker builder cache" "${before}"
        else
            ui_skipped "Docker builder cache" "Docker daemon not running"
        fi
    elif command -v docker >/dev/null 2>&1; then
        ui_dry "Docker builder cache" "?" "docker builder prune -f"
    fi
}

# Deep clean: removes Command Line Tools (requires sudo, --deep-clean only)
clean_command_line_tools() {
    [[ "${DO_DEEP_CLEAN:-false}" == "true" ]] || return 0
    if [[ -d "/Library/Developer/CommandLineTools" ]]; then
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            ui_dry "Xcode Command Line Tools" "$(path_size_h /Library/Developer/CommandLineTools)" "/Library/Developer/CommandLineTools"
        else
            sudo rm -rf -- "/Library/Developer/CommandLineTools" 2>/dev/null
            if [[ -e "/Library/Developer/CommandLineTools" ]]; then
                ui_skipped "Xcode Command Line Tools" "could not remove (try with sudo)"
            else
                ui_cleaned "Xcode Command Line Tools" "removed"
                mcu_oplog "removed" "/Library/Developer/CommandLineTools"
            fi
        fi
    else
        ui_skipped "Xcode Command Line Tools" "not found"
    fi
}
