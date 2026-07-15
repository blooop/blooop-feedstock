#!/bin/bash
# opencode bootstrap shim
#
# Installed by the `opencode-shim` conda package as $PREFIX/bin/opencode. This shim
# does NOT redistribute opencode. On first run it performs opencode's official
# install into ~/.opencode (byte-for-byte the same thing `curl | bash` produces),
# then execs the resulting binary.
#
# Why a shim instead of packaging the binary directly: opencode releases very
# frequently and has native install-method awareness (`opencode upgrade`). A binary
# dropped into a conda prefix is not the location opencode manages, so self-update
# would not work. By bootstrapping the real install under ~/.opencode, every native
# feature works and opencode manages its own updates there — this package never has
# to be re-published for a new opencode release.
#
# Env:
#   OPENCODE_VERSION       pin a version for the first-run install (else latest)
#   OPENCODE_INSTALLER_URL override the installer URL (default: opencode.ai/install)
#   DEBUG_SHIM=1           verbose diagnostics on stderr

debug() {
    if [ "${DEBUG_SHIM:-}" = "1" ]; then
        echo "[opencode-shim] $*" >&2
    fi
}

# The official installer hardcodes this install location ($HOME/.opencode/bin).
OPENCODE_BIN="$HOME/.opencode/bin/opencode"
INSTALLER_URL="${OPENCODE_INSTALLER_URL:-https://opencode.ai/install}"

# Recursion guard. opencode's official installer runs `opencode --version` (its
# check_version step) to detect an already-installed version. Because this shim IS
# `opencode` on PATH, that call re-enters this script; with the real binary not yet
# present it would launch the installer again — an infinite fork bomb. When we are
# the process running the installer we export _OPENCODE_SHIM_BOOTSTRAPPING, and on
# re-entry we refuse to bootstrap a second time: if the real binary somehow already
# exists we exec it (a legitimate version check), otherwise we exit non-zero so the
# installer sees "not installed" (it does `opencode --version 2>/dev/null || echo ""`)
# and proceeds with the install.
if [ -n "${_OPENCODE_SHIM_BOOTSTRAPPING:-}" ] && [ ! -x "$OPENCODE_BIN" ]; then
    debug "re-entered during bootstrap and no real binary yet — declining to recurse"
    exit 1
fi

debug "OPENCODE_BIN=$OPENCODE_BIN"
debug "INSTALLER_URL=$INSTALLER_URL"
debug "OPENCODE_VERSION=${OPENCODE_VERSION:-<latest>}"

fetch_installer() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$INSTALLER_URL"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$INSTALLER_URL"
    else
        echo "opencode: curl or wget is required to install opencode on first run." >&2
        return 1
    fi
}

# Run opencode's official installer non-interactively. It detects the platform,
# downloads the matching release binary, and lays it down at ~/.opencode/bin/opencode.
# --no-modify-path: don't touch shell rc files (this shim is already on PATH).
# VERSION (if OPENCODE_VERSION is set) is honored by the installer for pinning.
# _OPENCODE_SHIM_BOOTSTRAPPING guards against the installer re-entering this shim.
bootstrap() {
    local tmp
    tmp="$(mktemp)" || return 1
    trap "rm -f '$tmp'" RETURN
    if ! fetch_installer >"$tmp"; then
        return 1
    fi
    if [ ! -s "$tmp" ]; then
        echo "opencode: downloaded installer was empty." >&2
        return 1
    fi
    _OPENCODE_SHIM_BOOTSTRAPPING=1 VERSION="${OPENCODE_VERSION:-}" bash "$tmp" --no-modify-path >&2
}

if [ ! -x "$OPENCODE_BIN" ]; then
    echo "opencode: first run — performing one-time opencode install into $HOME/.opencode ..." >&2
    if ! bootstrap; then
        echo "opencode: installation failed (network access is required on first run)." >&2
        echo "          See https://opencode.ai/docs/" >&2
        exit 1
    fi
    if [ ! -x "$OPENCODE_BIN" ]; then
        echo "opencode: installer completed but no runnable binary was found at" >&2
        echo "          $OPENCODE_BIN" >&2
        exit 1
    fi
fi

debug "exec $OPENCODE_BIN $*"
exec "$OPENCODE_BIN" "$@"
