#!/bin/bash
# lib/core/config.sh — Config file loader and whitelist manager.
# Source this file; do not execute directly.

MCU_CONFIG_DIR="${HOME}/.config/maccleanup"
MCU_CONFIG_FILE="${MCU_CONFIG_DIR}/config.yaml"
MCU_WHITELIST_FILE="${MCU_CONFIG_DIR}/whitelist"
MCU_PURGE_PATHS_FILE="${MCU_CONFIG_DIR}/purge_paths"

# Populated arrays (filled by config_load)
MCU_WHITELIST=()
MCU_CLEAN_EXTRA_PATHS=()
MCU_PURGE_PATHS=()

# ── Bootstrap: create config dir and seed files if they don't exist ───────────
config_bootstrap() {
    mkdir -p "$MCU_CONFIG_DIR"

    # Seed user config from shipped defaults if it doesn't exist
    if [[ ! -f "$MCU_CONFIG_FILE" ]]; then
        local script_dir
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        local defaults="${script_dir}/../../config/defaults.yaml"
        if [[ -f "$defaults" ]]; then
            cp "$defaults" "$MCU_CONFIG_FILE"
        else
            # Minimal fallback if shipped defaults aren't found
            cat > "$MCU_CONFIG_FILE" <<'EOF'
version: "1"
general:
  dry_run: false
  log_dir: ~/Library/Logs/maccleanup
clean:
  extra_paths: []
  whitelist: []
  override: false
  min_size_mb: 0
  trash:
    enabled: true
purge:
  paths:
    - ~/Documents
    - ~/Downloads
    - ~/Desktop
    - ~/Developer
    - ~/dev
    - ~/Projects
    - ~/Code
  min_age_days: 14
installer:
  min_age_days: 3
EOF
        fi
        echo -e "${GRAY}Created default config: ${MCU_CONFIG_FILE}${NC}"
    fi

    # Seed whitelist file if missing
    if [[ ! -f "$MCU_WHITELIST_FILE" ]]; then
        cat > "$MCU_WHITELIST_FILE" <<'EOF'
# MacCleanUp — Whitelist
# Paths listed here will never be cleaned, even if matched by the built-in list.
# One path per line. Glob patterns (e.g. ~/Library/Caches/com.myapp.*) are supported.
# Add entries here directly, or run: maccleanup clean --whitelist
EOF
    fi
}

# ── Minimal YAML key extractor (pure bash, no yq/python required) ─────────────
# Extracts a scalar value for a dotted key path from a YAML file.
# Only handles simple key: value (string/bool/int) at the top two levels.
yaml_get() {
    local file="$1" keypath="$2"
    local IFS='.'
    read -ra keys <<< "$keypath"
    unset IFS

    local depth=${#keys[@]}
    local indent=0 current_depth=0 value=""
    local parent_key="" parent_matched=false
    local top_key="${keys[0]}"
    local sub_key="${keys[1]:-}"

    while IFS= read -r line; do
        # Skip comments and blank lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        # Top-level key (no leading spaces)
        if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*): ]]; then
            parent_key="${BASH_REMATCH[1]}"
            parent_matched=false
            [[ "$parent_key" == "$top_key" ]] && parent_matched=true
            if [[ "$depth" -eq 1 ]] && $parent_matched; then
                value=$(echo "$line" | sed 's/^[^:]*:[[:space:]]*//')
                echo "$value"
                return 0
            fi
        fi

        # Second-level key (two-space indent)
        if $parent_matched && [[ -n "$sub_key" ]] && \
           [[ "$line" =~ ^[[:space:]]{2}([a-zA-Z_][a-zA-Z0-9_]*): ]]; then
            local sk="${BASH_REMATCH[1]}"
            if [[ "$sk" == "$sub_key" ]]; then
                value=$(echo "$line" | sed 's/^[[:space:]]*[^:]*:[[:space:]]*//')
                echo "$value"
                return 0
            fi
        fi
    done < "$file"
}

# ── Load whitelist file into MCU_WHITELIST array ─────────────────────────────
# Safety: an existing-but-unreadable whitelist must halt callers rather than
# silently running as if nothing were protected.
config_load_whitelist() {
    MCU_WHITELIST=()
    [[ -f "$MCU_WHITELIST_FILE" ]] || return 0
    if [[ ! -r "$MCU_WHITELIST_FILE" ]]; then
        ui_fatal "Whitelist file exists but is unreadable: ${MCU_WHITELIST_FILE}"
    fi
    local line
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        # Expand tilde
        line="${line/#\~/$HOME}"
        MCU_WHITELIST+=("$line")
    done < "$MCU_WHITELIST_FILE"
}

# ── Load purge paths file into MCU_PURGE_PATHS array ─────────────────────────
config_load_purge_paths() {
    MCU_PURGE_PATHS=()
    if [[ -f "$MCU_PURGE_PATHS_FILE" ]]; then
        local line
        while IFS= read -r line; do
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ "$line" =~ ^[[:space:]]*$ ]] && continue
            line="${line/#\~/$HOME}"
            MCU_PURGE_PATHS+=("$line")
        done < "$MCU_PURGE_PATHS_FILE"
    fi
    # Fall back to config defaults if no purge_paths file
    if [[ ${#MCU_PURGE_PATHS[@]} -eq 0 ]]; then
        MCU_PURGE_PATHS=(
            "$HOME/Documents" "$HOME/Downloads" "$HOME/Desktop"
            "$HOME/Developer" "$HOME/dev" "$HOME/Projects" "$HOME/Code"
        )
    fi
}

# ── Load extra clean paths from config ───────────────────────────────────────
# Parses the clean.extra_paths list from config.yaml into MCU_CLEAN_EXTRA_PATHS
# Format stored: "path|mode|min_size_mb"
config_load_extra_clean_paths() {
    MCU_CLEAN_EXTRA_PATHS=()
    [[ -f "$MCU_CONFIG_FILE" ]] || return 0

    local in_clean=false in_extra=false line path mode min_size
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        # Detect clean: section
        [[ "$line" =~ ^clean: ]] && { in_clean=true; continue; }
        # Another top-level key resets
        if $in_clean && [[ "$line" =~ ^[a-zA-Z] ]]; then
            in_clean=false; in_extra=false; continue
        fi

        if $in_clean; then
            [[ "$line" =~ ^[[:space:]]{2}extra_paths: ]] && { in_extra=true; continue; }
            if $in_extra; then
                # End of list (another key at same indent)
                [[ "$line" =~ ^[[:space:]]{2}[a-zA-Z] ]] && { in_extra=false; continue; }
                # List entry
                if [[ "$line" =~ ^[[:space:]]{4}-[[:space:]]*path:[[:space:]]*(.+) ]]; then
                    path="${BASH_REMATCH[1]}"
                    path="${path/#\~/$HOME}"
                    mode="clean"; min_size="0"
                elif [[ "$line" =~ ^[[:space:]]{6}mode:[[:space:]]*(.+) ]]; then
                    mode="${BASH_REMATCH[1]}"
                elif [[ "$line" =~ ^[[:space:]]{6}min_size_mb:[[:space:]]*([0-9]+) ]]; then
                    min_size="${BASH_REMATCH[1]}"
                    # End of one entry — record it
                    [[ -n "$path" ]] && MCU_CLEAN_EXTRA_PATHS+=("${path}|${mode}|${min_size}")
                    path=""; mode="clean"; min_size="0"
                fi
            fi
        fi
    done < "$MCU_CONFIG_FILE"
}

# ── Full config load entry point ──────────────────────────────────────────────
config_load() {
    config_bootstrap
    config_load_whitelist
    config_load_purge_paths
    config_load_extra_clean_paths

    # Read scalar settings (with defaults)
    local dry_run_cfg
    dry_run_cfg=$(yaml_get "$MCU_CONFIG_FILE" "general.dry_run" 2>/dev/null || echo "false")
    if [[ "$dry_run_cfg" == "true" ]] && [[ "${DRY_RUN:-false}" != "true" ]]; then
        DRY_RUN="true"
    fi
}

# ── Interactive whitelist manager ─────────────────────────────────────────────
# Usage: whitelist_manage [paths_to_offer...]
# Shows a numbered menu; user picks paths to protect.
whitelist_manage() {
    local candidates=("$@")
    if [[ ${#candidates[@]} -eq 0 ]]; then
        echo "No paths to manage."
        return 0
    fi

    echo ""
    echo -e "${BOLD}Whitelist Manager${NC} — select paths to protect from cleanup"
    echo -e "${GRAY}(protected paths will never be cleaned, even on future runs)${NC}"
    echo ""

    local i=1
    for p in "${candidates[@]}"; do
        local protected=""
        is_whitelisted "$p" && protected=" ${GREEN}[protected]${NC}"
        echo -e "  ${BOLD}${i})${NC} ${p}${protected}"
        (( i++ ))
    done

    echo ""
    echo -e "${GRAY}Enter numbers to toggle (space-separated), or press Enter to skip:${NC}"
    local reply
    read -r reply

    local num
    for num in $reply; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le ${#candidates[@]} ]]; then
            local target="${candidates[$((num-1))]}"
            if is_whitelisted "$target"; then
                # Remove from whitelist
                local tmp
                tmp=$(grep -vxF "$target" "$MCU_WHITELIST_FILE" 2>/dev/null || true)
                echo "$tmp" > "$MCU_WHITELIST_FILE"
                echo -e "  ${YELLOW}Removed from whitelist:${NC} $target"
            else
                # Add to whitelist
                echo "$target" >> "$MCU_WHITELIST_FILE"
                echo -e "  ${GREEN}Added to whitelist:${NC} $target"
            fi
        fi
    done

    # Reload whitelist
    config_load_whitelist
}

# ── Whitelist CLI command handler ─────────────────────────────────────────────
# Usage: run_whitelist_cmd [list|add|remove|clear] [args...]
run_whitelist_cmd() {
    local action="${1:-list}"
    local target="${2:-}"

    case "$action" in
        list)
            echo -e "${BOLD}MacCleanUp — Whitelisted Paths${NC} (${MCU_WHITELIST_FILE})"
            if [[ ! -f "$MCU_WHITELIST_FILE" ]] || [[ ${#MCU_WHITELIST[@]} -eq 0 ]]; then
                echo "  (whitelist is empty)"
            else
                local p
                for p in "${MCU_WHITELIST[@]}"; do
                    echo -e "  ${GREEN}${ICON_OK}${NC} ${p}"
                done
            fi
            ;;
        add)
            if [[ -z "$target" ]]; then
                echo "Usage: maccleanup whitelist add <path>"
                return 1
            fi
            target="${target/#\~/$HOME}"
            if is_whitelisted "$target"; then
                echo -e "${YELLOW}Path is already whitelisted:${NC} $target"
            else
                echo "$target" >> "$MCU_WHITELIST_FILE"
                config_load_whitelist
                echo -e "${GREEN}${ICON_OK} Added to whitelist:${NC} $target"
            fi
            ;;
        remove)
            if [[ -z "$target" ]]; then
                echo "Usage: maccleanup whitelist remove <path>"
                return 1
            fi
            target="${target/#\~/$HOME}"
            if [[ -f "$MCU_WHITELIST_FILE" ]]; then
                local tmp
                tmp=$(grep -vxF "$target" "$MCU_WHITELIST_FILE" 2>/dev/null || true)
                echo "$tmp" > "$MCU_WHITELIST_FILE"
                config_load_whitelist
                echo -e "${GREEN}${ICON_OK} Removed from whitelist:${NC} $target"
            fi
            ;;
        clear)
            if [[ -f "$MCU_WHITELIST_FILE" ]]; then
                > "$MCU_WHITELIST_FILE"
                config_load_whitelist
                echo -e "${GREEN}${ICON_OK} Whitelist cleared.${NC}"
            fi
            ;;
        *)
            echo "Usage: maccleanup whitelist [list|add <path>|remove <path>|clear]"
            return 1
            ;;
    esac
}

# ── Config CLI command handler ───────────────────────────────────────────────
# Usage: run_config_cmd [show|edit|path|reset]
run_config_cmd() {
    local action="${1:-show}"

    case "$action" in
        show)
            echo -e "${BOLD}MacCleanUp — Current Configuration${NC} (${MCU_CONFIG_FILE})"
            echo ""
            if [[ -f "$MCU_CONFIG_FILE" ]]; then
                cat "$MCU_CONFIG_FILE"
            else
                echo "Config file not found."
            fi
            ;;
        edit)
            local editor="${EDITOR:-nano}"
            echo -e "Opening config in ${editor}..."
            "$editor" "$MCU_CONFIG_FILE"
            ;;
        path)
            echo "$MCU_CONFIG_FILE"
            ;;
        reset)
            local script_dir
            script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
            local defaults="${script_dir}/config/defaults.yaml"
            if [[ -f "$defaults" ]]; then
                cp "$defaults" "$MCU_CONFIG_FILE"
                echo -e "${GREEN}${ICON_OK} Reset configuration to default template.${NC}"
            else
                echo -e "${RED}Defaults template not found at ${defaults}.${NC}"
            fi
            ;;
        *)
            echo "Usage: maccleanup config [show|edit|path|reset]"
            return 1
            ;;
    esac
}
