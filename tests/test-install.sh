#!/bin/bash
# Test script for verifying package installations from the blooop channel
# This script tests that packages can be installed and executed correctly

set -e

CHANNEL="https://prefix.dev/blooop"
PASSED=0
FAILED=0
TESTS_RUN=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}

run_test() {
    local test_name="$1"
    local test_cmd="$2"

    ((TESTS_RUN++))
    log_info "Running test: $test_name"

    if eval "$test_cmd" 2>&1; then
        log_pass "$test_name"
        return 0
    else
        log_fail "$test_name"
        return 1
    fi
}

echo "========================================"
echo "blooop-feedstock Installation Tests"
echo "========================================"
echo ""
echo "Channel: $CHANNEL"
echo "Platform: $(uname -s)-$(uname -m)"
echo "Date: $(date -Iseconds)"
echo ""

# Test 1: Verify pixi is available
run_test "pixi is available" "pixi --version"

# Test 2: Channel is accessible
run_test "Channel is accessible" "curl -sf '${CHANNEL}/linux-64/repodata.json' -o /dev/null || curl -sf '${CHANNEL}/noarch/repodata.json' -o /dev/null"

# Test 3: Install claude-code package
log_info "Installing claude-code package..."
if pixi global install --channel "$CHANNEL" claude-code 2>&1; then
    log_pass "claude-code package installation"
    ((TESTS_RUN++))

    # Test 4: Verify claude binary exists
    run_test "claude binary exists" "which claude || command -v claude"

    # Test 5: claude binary is executable
    run_test "claude binary is executable" "test -x \$(which claude)"

    # Test 6: claude shim syntax check
    run_test "claude shim has valid syntax" "bash -n \$(which claude)"
else
    log_fail "claude-code package installation"
    ((TESTS_RUN++))
fi

# Test 7: Try to install devpod if available
log_info "Checking if devpod package is available..."
if curl -sf "${CHANNEL}/linux-64/repodata.json" 2>/dev/null | grep -q '"devpod-'; then
    log_info "Installing devpod package..."
    ((TESTS_RUN++))
    if pixi global install --channel "$CHANNEL" devpod 2>&1; then
        log_pass "devpod package installation"

        # Test 8: Verify devpod binary exists
        run_test "devpod binary exists" "which devpod || command -v devpod"
    else
        log_fail "devpod package installation"
    fi
else
    log_info "Skipping devpod test (package not in channel)"
fi

# Summary
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Tests run: $TESTS_RUN"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}TESTS FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}ALL TESTS PASSED${NC}"
    exit 0
fi
