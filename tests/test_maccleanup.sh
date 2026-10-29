#!/bin/bash
# tests/test_maccleanup.sh — Automated test suite for MacCleanUp (maccleanup).
# Run directly: bash tests/test_maccleanup.sh

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${DIR}/maccleanup"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

pass() {
    echo -e "  \033[0;32m✓\033[0m $1"
    (( TESTS_PASSED++ ))
    (( TESTS_RUN++ ))
}

fail() {
    echo -e "  \033[0;31m✗\033[0m $1: $2"
    (( TESTS_FAILED++ ))
    (( TESTS_RUN++ ))
}

echo "=========================================================="
echo " Running MacCleanUp (maccleanup) Test Suite"
echo "=========================================================="

# Test 1: Bash syntax check on all scripts
echo ""
echo "[Test Group 1] Shell Syntax Validation"
for f in "$BIN" "$DIR"/lib/**/*.sh; do
    [[ -f "$f" ]] || continue
    rel="${f#$DIR/}"
    if bash -n "$f" 2>/dev/null; then
        pass "Syntax valid: $rel"
    else
        fail "Syntax valid: $rel" "Syntax error detected"
    fi
done

# Test 2: Basic CLI flags
echo ""
echo "[Test Group 2] Core CLI Flags"
if "$BIN" --help >/dev/null 2>&1; then
    pass "maccleanup --help exits with 0"
else
    fail "maccleanup --help" "Non-zero exit"
fi

version_out=$("$BIN" --version 2>/dev/null || echo "")
if [[ "$version_out" =~ MacCleanUp.*v[0-9]+\.[0-9]+ ]]; then
    pass "maccleanup --version outputs valid version string"
else
    fail "maccleanup --version" "Output: '$version_out'"
fi

# Test 3: Whitelist functionality
echo ""
echo "[Test Group 3] Whitelist Management"
test_path="/tmp/maccleanup_test_whitelisted_path"

"$BIN" whitelist add "$test_path" >/dev/null 2>&1
if "$BIN" whitelist list 2>/dev/null | grep -q "$test_path"; then
    pass "maccleanup whitelist add & list"
else
    fail "maccleanup whitelist add" "Path not found in list"
fi

"$BIN" whitelist remove "$test_path" >/dev/null 2>&1
if ! "$BIN" whitelist list 2>/dev/null | grep -q "$test_path"; then
    pass "maccleanup whitelist remove"
else
    fail "maccleanup whitelist remove" "Path still present in list"
fi

# Test 4: Config command
echo ""
echo "[Test Group 4] Config Commands"
cfg_path=$("$BIN" config path 2>/dev/null || echo "")
if [[ -n "$cfg_path" && "$cfg_path" =~ config\.yaml$ ]]; then
    pass "maccleanup config path returns valid path ($cfg_path)"
else
    fail "maccleanup config path" "Output: '$cfg_path'"
fi

if "$BIN" config show >/dev/null 2>&1; then
    pass "maccleanup config show displays config without error"
else
    fail "maccleanup config show" "Failed to show config"
fi

# Test 5: Dry-run executions
echo ""
echo "[Test Group 5] Dry-Run Safe Executions"
if "$BIN" optimize --dry-run >/dev/null 2>&1; then
    pass "maccleanup optimize --dry-run succeeds"
else
    fail "maccleanup optimize --dry-run" "Command failed"
fi

if "$BIN" clean --dry-run >/dev/null 2>&1; then
    pass "maccleanup clean --dry-run succeeds"
else
    fail "maccleanup clean --dry-run" "Command failed"
fi

# Test 6: TouchID status check
echo ""
echo "[Test Group 6] Touch ID Subcommand"
if "$BIN" touchid status >/dev/null 2>&1; then
    pass "maccleanup touchid status runs cleanly"
else
    fail "maccleanup touchid status" "Command failed"
fi

# Test 7: Shell completions
echo ""
echo "[Test Group 7] Shell Tab Completion Generation"
zsh_comp=$("$BIN" completion zsh 2>/dev/null || echo "")
if [[ "$zsh_comp" =~ compdef[[:space:]]maccleanup ]]; then
    pass "maccleanup completion zsh produces valid compdef"
else
    fail "maccleanup completion zsh" "Missing compdef maccleanup"
fi

bash_comp=$("$BIN" completion bash 2>/dev/null || echo "")
if [[ "$bash_comp" =~ complete[[:space:]]-F ]]; then
    pass "maccleanup completion bash produces valid complete -F"
else
    fail "maccleanup completion bash" "Missing complete -F"
fi

# Test 8: Status one-shot mode
echo ""
echo "[Test Group 8] Status Monitor"
if STATUS_ONCE=true "$BIN" status --once >/dev/null 2>&1; then
    pass "maccleanup status --once takes snapshot and exits cleanly"
else
    fail "maccleanup status --once" "Status command failed"
fi

status_json=$("$BIN" status --json 2>/dev/null || echo "")
if echo "$status_json" | python3 -m json.tool >/dev/null 2>&1; then
    pass "maccleanup status --json outputs valid JSON"
else
    fail "maccleanup status --json" "Invalid JSON: '$status_json'"
fi

if echo "$status_json" | grep -q '"health_score"'; then
    pass "maccleanup status --json includes health_score"
else
    fail "maccleanup status --json health_score" "Field missing"
fi

# Test 9: Uninstall --list produces valid JSON
echo ""
echo "[Test Group 9] Uninstall JSON Listing"
uninstall_list=$("$BIN" uninstall --list 2>/dev/null || echo "")
if echo "$uninstall_list" | python3 -m json.tool >/dev/null 2>&1; then
    pass "maccleanup uninstall --list outputs valid JSON"
else
    fail "maccleanup uninstall --list" "Invalid JSON: '$uninstall_list'"
fi

# Test 10: Whitelist safety — unreadable whitelist file halts execution
echo ""
echo "[Test Group 10] Whitelist Safety"
wl_test_dir=$(mktemp -d)
wl_test_file="${wl_test_dir}/whitelist"
touch "$wl_test_file"
chmod 000 "$wl_test_file"
if bash -c "
    source '${DIR}/lib/core/ui.sh'
    source '${DIR}/lib/core/config.sh'
    MCU_WHITELIST_FILE='${wl_test_file}'
    config_load_whitelist
" >/dev/null 2>&1; then
    fail "Unreadable whitelist halts execution" "Expected non-zero exit, got success"
else
    pass "Unreadable whitelist halts execution (safety)"
fi
chmod 644 "$wl_test_file"
rm -rf "$wl_test_dir"

# Test 11: Optimize dry-run mentions new maintenance tasks
echo ""
echo "[Test Group 11] Optimize Coverage"
optimize_out=$("$BIN" optimize --dry-run 2>&1 || echo "")
if echo "$optimize_out" | grep -qi "Time Machine"; then
    pass "maccleanup optimize --dry-run includes snapshot thinning"
else
    fail "maccleanup optimize --dry-run" "Missing Time Machine snapshot thinning section"
fi

if echo "$optimize_out" | grep -qi "Temporary Files"; then
    pass "maccleanup optimize --dry-run includes TMPDIR cleanup"
else
    fail "maccleanup optimize --dry-run" "Missing Temporary Files section"
fi

# Test 12: Clean dry-run includes newly added modules
echo ""
echo "[Test Group 12] Clean Coverage"
clean_out=$("$BIN" clean --dry-run 2>&1 || echo "")
for section in "JetBrains IDEs" "Steam"; do
    if echo "$clean_out" | grep -q "$section"; then
        pass "maccleanup clean --dry-run includes $section section"
    else
        fail "maccleanup clean --dry-run" "Missing $section section"
    fi
done

echo ""
echo "=========================================================="
echo " Test Summary: ${TESTS_PASSED}/${TESTS_RUN} passed"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e " \033[0;31mFAILED: ${TESTS_FAILED} test(s)\033[0m"
    exit 1
else
    echo -e " \033[0;32mALL TESTS PASSED!\033[0m"
    exit 0
fi
