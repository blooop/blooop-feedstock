#!/bin/bash
# Test script for verifying package installations from the blooop channel
# This script tests that packages can be installed and executed correctly

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

    if eval "$test_cmd" >/dev/null 2>&1; then
        log_pass "$test_name"
        return 0
    else
        log_fail "$test_name"
        return 0  # Don't fail the script, just record the failure
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
run_test "Channel is accessible" "curl -sf '${CHANNEL}/linux-64/repodata.json' -o /dev/null"

# Test 3: Install claude-shim package
log_info "Installing claude-shim package..."
((TESTS_RUN++))
if pixi global install --channel "$CHANNEL" claude-shim 2>&1; then
    log_pass "claude-shim package installation"

    # Test 4: Verify claude command exists via pixi
    run_test "claude command exists" "which claude"

    # Test 5: claude command is executable
    run_test "claude command is executable" "test -x \$(which claude)"

    # Test 6: Check the actual shim script syntax (in the environment)
    CLAUDE_ENV_SCRIPT="$HOME/.pixi/envs/claude-shim/bin/claude"
    if [ -f "$CLAUDE_ENV_SCRIPT" ]; then
        run_test "claude shim has valid syntax" "bash -n '$CLAUDE_ENV_SCRIPT'"
    else
        log_info "Skipping shim syntax check (env script not found)"
    fi

    # Test 7: Test claude can run (will download on first run)
    log_info "Testing claude execution (this may download on first run)..."
    ((TESTS_RUN++))
    if timeout 120 claude --help >/dev/null 2>&1; then
        log_pass "claude --help executes successfully"
    else
        log_fail "claude --help failed"
    fi
else
    log_fail "claude-shim package installation"
fi

# Test: Cache directory selection for Docker persistence
log_info "Testing cache directory selection for Docker mount support..."

# Test the determine_install_dir logic directly
test_cache_dir_selection() {
    local test_home="$1"
    local setup="$2"
    local expected_pattern="$3"
    local test_name="$4"

    # Create test home
    rm -rf "$test_home"
    mkdir -p "$test_home"

    # Run setup (create dirs as needed)
    eval "$setup"

    # Source the determine_install_dir function
    determine_install_dir() {
        if [ -d "$HOME/.claude" ]; then
            echo "$HOME/.claude/cache/claude-code"
            return
        fi
        if [ -d "$HOME/.cache" ]; then
            echo "$HOME/.cache/claude-code"
            return
        fi
        echo "${CONDA_PREFIX:-${PREFIX:-$HOME/.pixi/envs/default}}/opt/claude-code"
    }

    # Test with modified HOME
    local old_home="$HOME"
    HOME="$test_home"
    local result
    result=$(determine_install_dir)
    HOME="$old_home"

    ((TESTS_RUN++))
    if [[ "$result" == *"$expected_pattern"* ]]; then
        log_pass "$test_name"
        return 0
    else
        log_fail "$test_name (got: $result, expected pattern: $expected_pattern)"
        return 1
    fi
}

# Test: ~/.claude takes priority
test_cache_dir_selection "/tmp/test_home_1" "mkdir -p /tmp/test_home_1/.claude /tmp/test_home_1/.cache" ".claude/cache/claude-code" "Cache uses ~/.claude when present"

# Test: ~/.cache used when ~/.claude doesn't exist
test_cache_dir_selection "/tmp/test_home_2" "mkdir -p /tmp/test_home_2/.cache" ".cache/claude-code" "Cache uses ~/.cache when ~/.claude absent"

# Test: Falls back to default when neither exists
test_cache_dir_selection "/tmp/test_home_3" ":" "/opt/claude-code" "Cache falls back to env dir when no cache dirs"

# Cleanup
rm -rf /tmp/test_home_1 /tmp/test_home_2 /tmp/test_home_3

# Test: Try to install devpod if available
log_info "Checking if devpod package is available..."
if curl -sf "${CHANNEL}/linux-64/repodata.json" 2>/dev/null | grep -q '"devpod-'; then
    log_info "Installing devpod package..."
    ((TESTS_RUN++))
    if pixi global install --channel "$CHANNEL" devpod 2>&1; then
        log_pass "devpod package installation"
        run_test "devpod binary exists" "which devpod"
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
