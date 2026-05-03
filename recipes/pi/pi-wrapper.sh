#!/bin/sh
# pi wrapper — runs the pi binary and handles `pi update` in-place
set -e

_DIR="$(cd "$(dirname "$0")" && pwd -P)"
INSTALL_DIR="$_DIR/../lib/pi"
VERSION_FILE="$INSTALL_DIR/.version"
REAL_BINARY="$INSTALL_DIR/pi"

_detect_asset() {
    case "$(uname -s)" in
        Linux)
            case "$(uname -m)" in
                x86_64)  echo "pi-linux-x64.tar.gz" ;;
                aarch64) echo "pi-linux-arm64.tar.gz" ;;
                *)       echo "" ;;
            esac ;;
        Darwin)
            case "$(uname -m)" in
                x86_64) echo "pi-darwin-x64.tar.gz" ;;
                arm64)  echo "pi-darwin-arm64.tar.gz" ;;
                *)      echo "" ;;
            esac ;;
        *) echo "" ;;
    esac
}

if [ "$1" = "update" ]; then
    ASSET=$(_detect_asset)
    if [ -z "$ASSET" ]; then
        echo "error: unsupported platform $(uname -s)/$(uname -m)" >&2
        exit 1
    fi

    CURRENT=$(cat "$VERSION_FILE" 2>/dev/null || echo "")
    LATEST=$(curl -sf "https://api.github.com/repos/badlogic/pi-mono/releases/latest" \
        | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')

    if [ -z "$LATEST" ]; then
        echo "error: could not fetch latest version from GitHub" >&2
        exit 1
    fi

    if [ "$CURRENT" = "$LATEST" ]; then
        echo "pi is already up to date (v$LATEST)"
        exit 0
    fi

    echo "Updating pi v${CURRENT:-unknown} -> v${LATEST}..."
    URL="https://github.com/badlogic/pi-mono/releases/download/v${LATEST}/${ASSET}"
    TMP=$(mktemp -d)
    trap "rm -rf '$TMP'" EXIT INT TERM
    curl -fSL --progress-bar -o "$TMP/pi.tar.gz" "$URL"
    mkdir -p "$TMP/extracted"
    tar -xzf "$TMP/pi.tar.gz" -C "$TMP/extracted" --strip-components=1
    cp -r "$TMP/extracted/." "$INSTALL_DIR/"
    chmod 755 "$REAL_BINARY"
    echo "$LATEST" > "$VERSION_FILE"
    trap - EXIT INT TERM
    rm -rf "$TMP"
    echo "pi updated to v${LATEST}"
    exit 0
fi

exec "$REAL_BINARY" "$@"
