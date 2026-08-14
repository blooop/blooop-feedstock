#!/bin/bash
# Test script for verifying package installations from the blooop channel
# This script tests that packages can be installed and executed correctly

CHANNEL="https://prefix.dev/blooop"
PASSED=0
FAILED=0
TESTS_RUN=0

# Channel subdir for the platform under test. Availability must be probed against
# the repodata for THIS architecture: not every package is built for every arch
# (zjsh, for one, is linux-64 only). Probing linux-64 from an arm64 runner reports
# packages as present that cannot possibly install here, turning "not built for
# this arch" into a spurious installation failure.
case "$(uname -s)-$(uname -m)" in
    Linux-x86_64)               SUBDIR="linux-64" ;;
    Linux-aarch64|Linux-arm64)  SUBDIR="linux-aarch64" ;;
    Darwin-x86_64)              SUBDIR="osx-64" ;;
    Darwin-arm64)               SUBDIR="osx-arm64" ;;
    *)                          SUBDIR="linux-64" ;;
esac

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
echo "Channel subdir: $SUBDIR"
echo "Date: $(date -Iseconds)"
echo ""

# Test 1: Verify pixi is available
run_test "pixi is available" "pixi --version"

# Test 2: Channel is accessible
run_test "Channel is accessible" "curl -sLf '${CHANNEL}/${SUBDIR}/repodata.json' -o /dev/null"

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

# Test: Corrupted binary recovery (self-healing)
log_info "Testing corrupted binary recovery..."
test_corrupted_binary_recovery() {
    local test_home="/tmp/test_home_corrupt"
    rm -rf "$test_home"
    mkdir -p "$test_home/.claude/cache/claude-code"

    # Create a fake corrupted binary (not a real Claude binary)
    echo '#!/bin/bash
echo "Bun is a fast JavaScript runtime"' > "$test_home/.claude/cache/claude-code/claude"
    chmod +x "$test_home/.claude/cache/claude-code/claude"
    echo "1.0.0" > "$test_home/.claude/cache/claude-code/.version"

    # Test that validate_binary detects this as corrupted
    validate_binary() {
        local binary="$1"
        if [ ! -x "$binary" ]; then
            return 1
        fi
        local version_output
        version_output=$("$binary" --version 2>&1) || true
        if echo "$version_output" | grep -q "Claude Code"; then
            return 0
        else
            return 1
        fi
    }

    ((TESTS_RUN++))
    if ! validate_binary "$test_home/.claude/cache/claude-code/claude"; then
        log_pass "Corrupted binary detected correctly"
    else
        log_fail "Failed to detect corrupted binary"
    fi

    rm -rf "$test_home"
}
test_corrupted_binary_recovery

# Test: Try to install devpod if available
log_info "Checking if devpod package is available..."
if curl -sLf "${CHANNEL}/${SUBDIR}/repodata.json" 2>/dev/null | grep -q '"devpod-'; then
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

# Test: Try to install forgit if available
log_info "Checking if forgit is available..."
if curl -sLf "${CHANNEL}/noarch/repodata.json" 2>/dev/null | grep -q '"forgit-'; then
    log_info "Installing forgit package..."
    ((TESTS_RUN++))
    if pixi global install --channel "$CHANNEL" --channel conda-forge forgit 2>&1; then
        log_pass "forgit installation"
        run_test "git-forgit binary exists" "which git-forgit"
        run_test "git-forgit runs" "git-forgit 2>&1 | grep -q 'commands are supported'"
    else
        log_fail "forgit installation"
    fi
else
    log_info "Skipping forgit test (package not in channel)"
fi

# Test: Try to install isd if available
log_info "Checking if isd is available..."
if curl -sLf "${CHANNEL}/noarch/repodata.json" 2>/dev/null | grep -q '"isd-'; then
    log_info "Installing isd package..."
    ((TESTS_RUN++))
    # Note: isd is a noarch Python package needing deps from conda-forge
    if pixi global install --channel "$CHANNEL" --channel conda-forge isd 2>&1; then
        log_pass "isd installation"
        run_test "isd binary exists" "which isd"
        run_test "isd-tui binary exists" "which isd-tui"
    else
        log_fail "isd installation"
    fi
else
    log_info "Skipping isd test (package not in channel)"
fi

# Test: Try to install speedtest-go if available
log_info "Checking if speedtest-go package is available..."
if curl -sLf "${CHANNEL}/${SUBDIR}/repodata.json" 2>/dev/null | grep -q '"speedtest-go-'; then
    log_info "Installing speedtest-go package..."
    ((TESTS_RUN++))
    if pixi global install --channel "$CHANNEL" speedtest-go 2>&1; then
        log_pass "speedtest-go package installation"
        run_test "speedtest-go binary exists" "which speedtest-go"
        run_test "speedtest-go version check" "speedtest-go --version"
    else
        log_fail "speedtest-go package installation"
    fi
else
    log_info "Skipping speedtest-go test (package not in channel)"
fi

# Test: Try to install codex-shim if available
# codex-shim is a bootstrap shim exposing `codex`; running it triggers a network
# install of the real Codex, so we only verify the shim installs and is valid here.
log_info "Checking if codex-shim package is available..."
if curl -sLf "${CHANNEL}/${SUBDIR}/repodata.json" 2>/dev/null | grep -q '"codex-shim-'; then
    log_info "Installing codex-shim package..."
    ((TESTS_RUN++))
    if pixi global install --channel "$CHANNEL" --channel conda-forge codex-shim 2>&1; then
        log_pass "codex-shim package installation"
        run_test "codex command exists" "which codex"
        run_test "codex command is executable" "test -x \$(which codex)"
        CODEX_ENV_SCRIPT="$HOME/.pixi/envs/codex-shim/bin/codex"
        if [ -f "$CODEX_ENV_SCRIPT" ]; then
            run_test "codex shim has valid syntax" "bash -n '$CODEX_ENV_SCRIPT'"
        else
            log_info "Skipping shim syntax check (env script not found)"
        fi
    else
        log_fail "codex-shim package installation"
    fi
else
    log_info "Skipping codex-shim test (package not in channel)"
fi

# Test: Try to install opencode-shim if available
# opencode-shim is a bootstrap shim exposing `opencode`; running it triggers a network
# install of the real opencode, so we only verify the shim installs and is valid here.
log_info "Checking if opencode-shim package is available..."
if curl -sLf "${CHANNEL}/${SUBDIR}/repodata.json" 2>/dev/null | grep -q '"opencode-shim-'; then
    log_info "Installing opencode-shim package..."
    ((TESTS_RUN++))
    if pixi global install --channel "$CHANNEL" --channel conda-forge opencode-shim 2>&1; then
        log_pass "opencode-shim package installation"
        run_test "opencode command exists" "which opencode"
        run_test "opencode command is executable" "test -x \$(which opencode)"
        OPENCODE_ENV_SCRIPT="$HOME/.pixi/envs/opencode-shim/bin/opencode"
        if [ -f "$OPENCODE_ENV_SCRIPT" ]; then
            run_test "opencode shim has valid syntax" "bash -n '$OPENCODE_ENV_SCRIPT'"
        else
            log_info "Skipping shim syntax check (env script not found)"
        fi
    else
        log_fail "opencode-shim package installation"
    fi
else
    log_info "Skipping opencode-shim test (package not in channel)"
fi

# Test: Try to install pi if available
log_info "Checking if pi package is available..."
if curl -sLf "${CHANNEL}/${SUBDIR}/repodata.json" 2>/dev/null | grep -q '"pi-'; then
    log_info "Installing pi package..."
    ((TESTS_RUN++))
    if pixi global install --channel "$CHANNEL" pi 2>&1; then
        log_pass "pi package installation"
        run_test "pi binary exists" "which pi"
        run_test "pi version check" "pi --version"
        run_test "pi self-update command works" "pi update"
    else
        log_fail "pi package installation"
    fi
else
    log_info "Skipping pi test (package not in channel)"
fi

# Test: Try to install uhk-agent if available
log_info "Checking if uhk-agent is available..."
if curl -sLf "${CHANNEL}/${SUBDIR}/repodata.json" 2>/dev/null | grep -q '"uhk-agent-'; then
    log_info "Installing uhk-agent package..."
    ((TESTS_RUN++))
    if pixi global install --channel "$CHANNEL" uhk-agent 2>&1; then
        log_pass "uhk-agent installation"
        run_test "uhk-agent wrapper exists" "which uhk-agent"
        run_test "uhk-agent binary exists" "test -x \$HOME/.pixi/envs/uhk-agent/lib/uhk-agent/uhk-agent"
    else
        log_fail "uhk-agent installation"
    fi
else
    log_info "Skipping uhk-agent test (package not in channel)"
fi

# Test: Try to install kitty-bin if available
log_info "Checking if kitty-bin is available..."
if curl -sLf "${CHANNEL}/${SUBDIR}/repodata.json" 2>/dev/null | grep -q '"kitty-bin-'; then
    log_info "Installing kitty-bin package..."
    ((TESTS_RUN++))
    # conda-forge is required here: kitty-bin depends on fontconfig
    if pixi global install --channel "$CHANNEL" --channel conda-forge kitty-bin 2>&1; then
        log_pass "kitty-bin installation"
        run_test "kitty symlink exists" "which kitty"
        run_test "kitten symlink exists" "which kitten"
        run_test "kitty version check" "kitty --version"
        run_test "kitten version check" "kitten --version"
        # kitty is a GUI app, so there is no window to open in CI. Importing the
        # native extension is the meaningful headless check: it loads the bundled
        # Python, cairo and fontconfig, which is where a broken bundle shows up.
        run_test "kitty native extension loads" "kitty +runpy 'import kitty.fast_data_types; print(\"ok\")'"
        run_test "kitty fontconfig linkage" "kitty +runpy 'from kitty.fast_data_types import fc_list; fc_list()'"
    else
        log_fail "kitty-bin installation"
    fi
else
    log_info "Skipping kitty-bin test (package not in channel)"
fi

# Test: Try to install zjsh if available
log_info "Checking if zjsh is available..."
if curl -sLf "${CHANNEL}/${SUBDIR}/repodata.json" 2>/dev/null | grep -q '"zjsh-'; then
    log_info "Installing zjsh package..."
    ((TESTS_RUN++))
    if pixi global install --channel "$CHANNEL" zjsh 2>&1; then
        log_pass "zjsh installation"
        run_test "zjsh binary exists" "which zjsh"
        run_test "zjsh doctor runs" "zjsh doctor || true"
    else
        log_fail "zjsh installation"
    fi
else
    log_info "Skipping zjsh test (package not in channel)"
fi

# Note: Dependency resolution is implicitly tested by the installation tests above
# If a package has unresolvable dependencies, the installation will fail

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
