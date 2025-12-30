#!/bin/bash
# Claude Code Shim - Downloads and executes the official Claude Code binary
# This shim does NOT redistribute the Claude Code binary, but downloads it on-demand

set -e

# Version of Claude Code this shim is designed for
CLAUDE_VERSION="${PKG_VERSION:-2.0.68}"

# Determine platform and architecture
get_platform_info() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)

    case "$os" in
        linux)
            case "$arch" in
                x86_64) echo "linux-x64" ;;
                aarch64|arm64) echo "linux-arm64" ;;
                *) echo "unsupported" ;;
            esac
            ;;
        darwin)
            case "$arch" in
                x86_64) echo "darwin-x64" ;;
                arm64) echo "darwin-arm64" ;;
                *) echo "unsupported" ;;
            esac
            ;;
        mingw*|msys*|cygwin*)
            case "$arch" in
                x86_64) echo "win32-x64" ;;
                *) echo "unsupported" ;;
            esac
            ;;
        *)
            echo "unsupported"
            ;;
    esac
}

# Installation directory for the real Claude Code binary
INSTALL_DIR="${CONDA_PREFIX:-${PREFIX:-$HOME/.pixi/envs/default}}/opt/claude-code"
REAL_BINARY="$INSTALL_DIR/bin/claude"

# Check if we're on Windows
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    REAL_BINARY="$INSTALL_DIR/bin/claude.exe"
fi

# Function to download and install Claude Code
install_claude_code() {
    echo "🔍 Claude Code not found. Downloading official installer..."

    # Get platform information
    PLATFORM=$(get_platform_info)
    if [ "$PLATFORM" == "unsupported" ]; then
        echo "❌ Error: Unsupported platform $(uname -s)/$(uname -m)"
        exit 1
    fi

    # Construct download URL
    BASE_URL="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819"
    DOWNLOAD_URL="$BASE_URL/$CLAUDE_VERSION/claude-$PLATFORM.tar.gz"

    # Windows uses zip instead of tar.gz
    if [[ "$PLATFORM" == win32* ]]; then
        DOWNLOAD_URL="$BASE_URL/$CLAUDE_VERSION/claude-$PLATFORM.zip"
    fi

    echo "📥 Downloading from: $DOWNLOAD_URL"

    # Create temporary directory for download
    TMP_DIR=$(mktemp -d)
    trap "rm -rf $TMP_DIR" EXIT

    # Download the installer
    if command -v curl &> /dev/null; then
        curl -fsSL -o "$TMP_DIR/claude-installer.tar.gz" "$DOWNLOAD_URL" || {
            echo "❌ Download failed. Please check your internet connection."
            exit 1
        }
    elif command -v wget &> /dev/null; then
        wget -q -O "$TMP_DIR/claude-installer.tar.gz" "$DOWNLOAD_URL" || {
            echo "❌ Download failed. Please check your internet connection."
            exit 1
        }
    else
        echo "❌ Error: Neither curl nor wget found. Please install one of them."
        exit 1
    fi

    echo "📦 Installing to: $INSTALL_DIR"

    # Create installation directory
    mkdir -p "$INSTALL_DIR"

    # Extract the archive
    if [[ "$PLATFORM" == win32* ]]; then
        unzip -q "$TMP_DIR/claude-installer.tar.gz" -d "$INSTALL_DIR"
    else
        tar -xzf "$TMP_DIR/claude-installer.tar.gz" -C "$INSTALL_DIR"
    fi

    # Make the binary executable
    chmod +x "$REAL_BINARY" 2>/dev/null || true

    echo "✅ Claude Code $CLAUDE_VERSION installed successfully!"
    echo ""
}

# Main logic: Check if binary exists, install if needed, then execute
if [ ! -f "$REAL_BINARY" ]; then
    install_claude_code
fi

# Verify the binary exists after installation
if [ ! -f "$REAL_BINARY" ]; then
    echo "❌ Error: Installation failed. Binary not found at: $REAL_BINARY"
    exit 1
fi

# Execute the real Claude Code binary with all arguments
exec "$REAL_BINARY" "$@"
