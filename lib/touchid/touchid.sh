#!/bin/bash
# lib/touchid/touchid.sh — Configure Touch ID for sudo authentication.
# Source this file; do not execute directly.

TOUCHID_SUDO_FILE="/etc/pam.d/sudo"
TOUCHID_RULE="auth       sufficient     pam_tid.so"

_touchid_is_enabled() {
    grep -qF "pam_tid.so" "$TOUCHID_SUDO_FILE" 2>/dev/null
}

run_touchid() {
    local action="${1:-status}"

    case "$action" in
        --enable|enable)
            if _touchid_is_enabled; then
                echo -e "${GREEN}${ICON_OK} Touch ID for sudo is already enabled.${NC}"
                return 0
            fi
            echo -e "Adding Touch ID entry to ${TOUCHID_SUDO_FILE}..."
            # Insert after the first non-comment line (# headers)
            sudo awk '
                /^#/ { print; next }
                !inserted { print "'"$TOUCHID_RULE"'"; inserted=1 }
                { print }
            ' "$TOUCHID_SUDO_FILE" > /tmp/cmp_sudo_pam && \
            sudo cp /tmp/cmp_sudo_pam "$TOUCHID_SUDO_FILE" && \
            rm -f /tmp/cmp_sudo_pam
            if _touchid_is_enabled; then
                echo -e "${GREEN}${ICON_OK} Touch ID for sudo is now enabled.${NC}"
                mcu_oplog "enabled" "Touch ID for sudo"
            else
                echo -e "${RED}Failed to enable Touch ID for sudo. Check permissions.${NC}"
                return 1
            fi
            ;;

        --disable|disable)
            if ! _touchid_is_enabled; then
                echo -e "${GRAY}Touch ID for sudo is already disabled.${NC}"
                return 0
            fi
            sudo sed -i '' '/pam_tid.so/d' "$TOUCHID_SUDO_FILE"
            echo -e "${YELLOW}Touch ID for sudo disabled.${NC}"
            mcu_oplog "disabled" "Touch ID for sudo"
            ;;

        --status|status|"")
            echo -e "${BOLD}Touch ID for sudo — Status${NC}"
            if _touchid_is_enabled; then
                echo -e "  ${GREEN}${ICON_OK} Enabled${NC} — Touch ID can be used to authenticate sudo commands"
            else
                echo -e "  ${GRAY}${ICON_SKIP} Disabled${NC} — password required for sudo"
                echo -e "  ${GRAY}Run: maccleanup touchid --enable  to enable Touch ID${NC}"
            fi

            # Warn about macOS update resetting this
            echo ""
            echo -e "${GRAY}Note: macOS updates can reset ${TOUCHID_SUDO_FILE}."
            echo -e "If Touch ID stops working after an update, re-run: maccleanup touchid --enable${NC}"
            ;;

        *)
            echo "Usage: maccleanup touchid [--enable | --disable | --status]"
            return 1
            ;;
    esac
}
