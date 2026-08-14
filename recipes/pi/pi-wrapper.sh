#!/bin/sh
# pi wrapper — runs the pi binary and handles `pi update` in-place
set -e

_DIR="$(cd "$(dirname "$0")" && pwd -P)"
INSTALL_DIR="$_DIR/../lib/pi"
VERSION_FILE="$INSTALL_DIR/.version"
REAL_BINARY="$INSTALL_DIR/pi"

# Upstream repo that `pi update` pulls releases from. This was badlogic/pi-mono
# until upstream renamed it; GitHub still redirects the old path, but naming the
# current repo keeps updates working if that redirect is ever retired.
# Override to track a fork or a different release stream.
PI_REPO="${PI_REPO:-earendil-works/pi}"

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

_http_get() {
    URL="$1"
    if command -v curl >/dev/null 2>&1; then
        curl -sfL "$URL"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$URL"
    else
        echo "error: pi update requires curl or wget in PATH" >&2
        exit 1
    fi
}

_download_file() {
    URL="$1"
    OUT="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fSL --progress-bar -o "$OUT" "$URL"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$OUT" "$URL"
    else
        echo "error: pi update requires curl or wget in PATH" >&2
        exit 1
    fi
}

# Resolve the latest pi version WITHOUT hitting the rate-limited GitHub API.
#
# api.github.com allows only 60 unauthenticated requests/hour/IP. CI runners and
# anyone behind a shared IP or VPN exhaust that budget easily, and the API then
# returns 403 with no tag_name — so the parse below yielded an empty string and
# `pi update` aborted with "could not fetch latest version" even though the
# download itself never needs the API at all.
#
# github.com/<repo>/releases/latest instead redirects to .../releases/tag/vX.Y.Z,
# a plain web request with no such limit. -L is required for two hops: upstream
# renamed the repo (badlogic/pi-mono -> earendil-works/pi), so the rename
# redirect comes first and the tag only appears after following it.
#
# Prints the bare version (e.g. 0.84.1); prints nothing and returns non-zero on
# failure. Needs curl for --write-out, so wget-only systems fall back to the API.
_resolve_latest_via_redirect() {
    command -v curl >/dev/null 2>&1 || return 1
    _eff=$(curl -fsSL -o /dev/null -w '%{url_effective}' \
        "https://github.com/${PI_REPO}/releases/latest" 2>/dev/null) || return 1
    case "$_eff" in
        */releases/tag/v[0-9]*) printf '%s\n' "${_eff##*/tag/v}" ;;
        *) return 1 ;;
    esac
}

if [ "$1" = "update" ]; then
    ASSET=$(_detect_asset)
    if [ -z "$ASSET" ]; then
        echo "error: unsupported platform $(uname -s)/$(uname -m)" >&2
        exit 1
    fi

    CURRENT=$(cat "$VERSION_FILE" 2>/dev/null || echo "")
    # Redirect-based lookup first (no rate limit); the API is the fallback for
    # wget-only systems. `|| true` keeps `set -e` from killing the script here so
    # the fallback actually gets a turn.
    LATEST=$(_resolve_latest_via_redirect || true)
    if [ -z "$LATEST" ]; then
        LATEST=$(_http_get "https://api.github.com/repos/${PI_REPO}/releases/latest" \
            | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/' || true)
    fi

    if [ -z "$LATEST" ]; then
        echo "error: could not fetch latest version from GitHub" >&2
        exit 1
    fi

    if [ "$CURRENT" = "$LATEST" ]; then
        echo "pi is already up to date (v$LATEST)"
        exit 0
    fi

    echo "Updating pi v${CURRENT:-unknown} -> v${LATEST}..."
    URL="https://github.com/${PI_REPO}/releases/download/v${LATEST}/${ASSET}"
    TMP=$(mktemp -d)
    trap "rm -rf '$TMP'" EXIT INT TERM
    _download_file "$URL" "$TMP/pi.tar.gz"
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
