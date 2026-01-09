#!/bin/bash
# Claude Code Shim - Downloads and executes the official Claude Code binary
# This shim does NOT redistribute the Claude Code binary, but downloads it on-demand

set -e

# GCS bucket URL for Claude Code releases
GCS_BUCKET="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

# Installation directory for the real Claude Code binary
INSTALL_DIR="${CONDA_PREFIX:-${PREFIX:-$HOME/.pixi/envs/default}}/opt/claude-code"
VERSION_FILE="$INSTALL_DIR/.version"
REAL_BINARY="$INSTALL_DIR/claude"

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

# Get latest stable version from GCS
get_latest_version() {
    download "$GCS_BUCKET/stable" 2>/dev/null || echo ""
}

# Install Claude Code binary
install_claude_code() {
    local version="$1"
    local platform="$2"

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

# Check if we need to install or update
if [ ! -f "$REAL_BINARY" ]; then
    # No binary installed
    if [ -z "$LATEST_VERSION" ]; then
        echo "Error: Cannot fetch latest version and no local installation found." >&2
        exit 1
    fi
    install_claude_code "$LATEST_VERSION" "$PLATFORM"
elif [ -n "$LATEST_VERSION" ] && [ "$LATEST_VERSION" != "$INSTALLED_VERSION" ]; then
    # Update available
    echo "Update available: ${INSTALLED_VERSION:-unknown} -> $LATEST_VERSION"
    install_claude_code "$LATEST_VERSION" "$PLATFORM"
fi

# Execute the real Claude Code binary with all arguments
exec "$REAL_BINARY" "$@"
