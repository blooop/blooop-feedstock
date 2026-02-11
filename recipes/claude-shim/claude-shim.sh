#!/bin/bash
# Claude Code Shim - Downloads and executes the official Claude Code binary
# This shim does NOT redistribute the Claude Code binary, but downloads it on-demand
#
# Behavior:
# 1. If official Claude install exists (~/.local/bin/claude), defer to it
# 2. Otherwise, download and install to the conda/pixi environment

set -e

# Debug mode: set DEBUG_SHIM=1 to see diagnostic info
debug() {
    if [ "${DEBUG_SHIM:-}" = "1" ]; then
        echo "[DEBUG] $*" >&2
    fi
}

debug "Shim version: 0.3.1"
debug "HOME=$HOME"
debug "CONDA_PREFIX=${CONDA_PREFIX:-unset}"

# Check for existing official Claude installation first
# The official installer puts claude at ~/.local/bin/claude -> ~/.local/share/claude/
OFFICIAL_CLAUDE="$HOME/.local/bin/claude"
if [ -x "$OFFICIAL_CLAUDE" ] && [ -d "$HOME/.local/share/claude" ]; then
    exec "$OFFICIAL_CLAUDE" "$@"
fi

# GCS bucket URL for Claude Code releases
GCS_BUCKET="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

# Check if a directory is writable (or can be created)
is_writable_dir() {
    local dir="$1"
    if [ -d "$dir" ]; then
        # Directory exists, check if writable
        [ -w "$dir" ]
    else
        # Directory doesn't exist, check if parent is writable
        local parent
        parent=$(dirname "$dir")
        [ -d "$parent" ] && [ -w "$parent" ]
    fi
}

# Determine cache directory for the binary
# Priority: ~/.claude/cache (if ~/.claude exists and writable) > ~/.cache/claude-code (if ~/.cache exists and writable) > conda/pixi env
determine_install_dir() {
    local cache_dir

    # Check for ~/.claude directory (can be mounted in Docker)
    if [ -d "$HOME/.claude" ]; then
        cache_dir="$HOME/.claude/cache/claude-code"
        if is_writable_dir "$HOME/.claude/cache" || is_writable_dir "$HOME/.claude"; then
            debug "~/.claude exists and is writable, using it for cache"
            echo "$cache_dir"
            return
        fi
        debug "~/.claude exists but is not writable"
    else
        debug "~/.claude does not exist"
    fi

    # Check for ~/.cache directory (XDG standard, can be mounted in Docker)
    if [ -d "$HOME/.cache" ]; then
        cache_dir="$HOME/.cache/claude-code"
        if is_writable_dir "$cache_dir" || is_writable_dir "$HOME/.cache"; then
            debug "~/.cache exists and is writable, using it for cache"
            echo "$cache_dir"
            return
        fi
        debug "~/.cache exists but is not writable"
    else
        debug "~/.cache does not exist"
    fi

    # Fall back to conda/pixi environment directory
    debug "Falling back to conda/pixi env directory"
    echo "${CONDA_PREFIX:-${PREFIX:-$HOME/.pixi/envs/default}}/opt/claude-code"
}

# Validate that a Claude binary works correctly
# Returns 0 if valid, 1 if invalid/corrupted
validate_binary() {
    local binary="$1"

    # Check file exists and is executable
    if [ ! -x "$binary" ]; then
        debug "Binary not executable: $binary"
        return 1
    fi

    # Run with --version and check output contains "Claude Code"
    local version_output
    version_output=$("$binary" --version 2>&1) || true

    if echo "$version_output" | grep -q "Claude Code"; then
        debug "Binary validation passed: $version_output"
        return 0
    else
        debug "Binary validation failed. Output: $version_output"
        return 1
    fi
}

# Installation directory for the real Claude Code binary
INSTALL_DIR="$(determine_install_dir)"
VERSION_FILE="$INSTALL_DIR/.version"
REAL_BINARY="$INSTALL_DIR/claude"

debug "INSTALL_DIR=$INSTALL_DIR"
debug "REAL_BINARY=$REAL_BINARY"
debug "Binary exists: $([ -f "$REAL_BINARY" ] && echo YES || echo NO)"

# Detect platform
detect_platform() {
    local os arch platform

    case "$(uname -s)" in
        Darwin) os="darwin" ;;
        Linux) os="linux" ;;
        MINGW*|MSYS*|CYGWIN*) os="win32" ;;
        *) echo "unsupported"; return ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64) arch="x64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) echo "unsupported"; return ;;
    esac

    # Check for musl on Linux
    if [ "$os" = "linux" ]; then
        if [ -f /lib/libc.musl-x86_64.so.1 ] || [ -f /lib/libc.musl-aarch64.so.1 ] || ldd /bin/ls 2>&1 | grep -q musl; then
            platform="linux-${arch}-musl"
        else
            platform="linux-${arch}"
        fi
    else
        platform="${os}-${arch}"
    fi

    echo "$platform"
}

# Download function
download() {
    local url="$1"
    local output="$2"

    if command -v curl &> /dev/null; then
        if [ -n "$output" ]; then
            curl -fsSL -o "$output" "$url"
        else
            curl -fsSL "$url"
        fi
    elif command -v wget &> /dev/null; then
        if [ -n "$output" ]; then
            wget -q -O "$output" "$url"
        else
            wget -q -O - "$url"
        fi
    else
        echo "Error: Neither curl nor wget found" >&2
        return 1
    fi
}

# Get installed version
get_installed_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    fi
}

# Get latest version from GCS
get_latest_version() {
    download "$GCS_BUCKET/stable" 2>/dev/null || echo ""
}

# Install Claude Code binary
install_claude_code() {
    local version="$1"
    local platform="$2"
    local is_update="$3"

    if [ "$is_update" != "true" ]; then
        echo "First run: Setting up Claude Code..."
        echo "This one-time download will fetch the official binary."
        echo ""
    fi

    echo "Downloading Claude Code v${version} for ${platform}..."

    # Create temporary file for download
    local tmp_binary
    tmp_binary=$(mktemp)
    trap "rm -f '$tmp_binary'" EXIT

    # Download the binary
    if ! download "$GCS_BUCKET/$version/$platform/claude" "$tmp_binary"; then
        echo "Download failed. Please check your internet connection." >&2
        exit 1
    fi

    # Verify checksum if jq is available
    local manifest_json expected_checksum actual_checksum
    manifest_json=$(download "$GCS_BUCKET/$version/manifest.json" 2>/dev/null || echo "")

    if [ -n "$manifest_json" ]; then
        if command -v jq &> /dev/null; then
            expected_checksum=$(echo "$manifest_json" | jq -r ".platforms[\"$platform\"].checksum // empty")
        else
            # Simple extraction without jq using bash string manipulation
            local json_oneline
            json_oneline=$(echo "$manifest_json" | tr -d '\n\r\t ')
            # Extract everything after the platform key, then after "checksum":"
            local after_platform="${json_oneline#*\"$platform\"}"
            local after_checksum="${after_platform#*\"checksum\":\"}"
            # Get first 64 characters (the checksum)
            expected_checksum="${after_checksum:0:64}"
            # Validate it looks like a checksum (64 hex chars)
            if ! echo "$expected_checksum" | grep -qE '^[a-f0-9]{64}$'; then
                expected_checksum=""
            fi
        fi

        if [ -n "$expected_checksum" ]; then
            if command -v sha256sum &> /dev/null; then
                actual_checksum=$(sha256sum "$tmp_binary" | cut -d' ' -f1)
            elif command -v shasum &> /dev/null; then
                actual_checksum=$(shasum -a 256 "$tmp_binary" | cut -d' ' -f1)
            fi

            if [ -n "$actual_checksum" ] && [ "$actual_checksum" != "$expected_checksum" ]; then
                echo "Checksum verification failed!" >&2
                echo "Expected: $expected_checksum" >&2
                echo "Actual:   $actual_checksum" >&2
                exit 1
            fi
        fi
    fi

    # Create installation directory
    mkdir -p "$INSTALL_DIR"

    # Move binary to installation directory
    mv "$tmp_binary" "$REAL_BINARY"
    chmod +x "$REAL_BINARY"
    trap - EXIT  # Clear trap since we moved the file

    # Save version info
    echo "$version" > "$VERSION_FILE"

    echo "Claude Code v${version} installed successfully!"
    echo ""
}

# Main logic
PLATFORM=$(detect_platform)
if [ "$PLATFORM" = "unsupported" ]; then
    echo "Error: Unsupported platform $(uname -s)/$(uname -m)" >&2
    exit 1
fi

LATEST_VERSION=$(get_latest_version)
INSTALLED_VERSION=$(get_installed_version)

# Check if we need to install, update, or repair
NEED_INSTALL="false"
IS_REPAIR="false"

if [ ! -f "$REAL_BINARY" ]; then
    # No binary installed
    debug "Binary not found, need fresh install"
    NEED_INSTALL="true"
elif ! validate_binary "$REAL_BINARY"; then
    # Binary exists but is corrupted
    echo "Cached binary appears corrupted, will re-download..."
    rm -f "$REAL_BINARY" "$VERSION_FILE"
    NEED_INSTALL="true"
    IS_REPAIR="true"
elif [ -n "$LATEST_VERSION" ] && [ "$LATEST_VERSION" != "$INSTALLED_VERSION" ]; then
    # Update available
    echo "Update available: ${INSTALLED_VERSION:-unknown} -> $LATEST_VERSION"
    NEED_INSTALL="true"
fi

if [ "$NEED_INSTALL" = "true" ]; then
    if [ -z "$LATEST_VERSION" ]; then
        echo "Error: Cannot fetch latest version and no local installation found." >&2
        exit 1
    fi
    if [ "$IS_REPAIR" = "true" ]; then
        install_claude_code "$LATEST_VERSION" "$PLATFORM" "true"
    elif [ ! -f "$REAL_BINARY" ]; then
        install_claude_code "$LATEST_VERSION" "$PLATFORM" "false"
    else
        install_claude_code "$LATEST_VERSION" "$PLATFORM" "true"
    fi
fi

# Execute the real Claude Code binary with all arguments
exec "$REAL_BINARY" "$@"
