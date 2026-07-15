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
#   OPENCODE_REPO          upstream repo used to resolve the latest version tag
#                          (default: anomalyco/opencode)
#   DEBUG_SHIM=1           verbose diagnostics on stderr

debug() {
    if [ "${DEBUG_SHIM:-}" = "1" ]; then
        echo "[opencode-shim] $*" >&2
    fi
}

# The official installer hardcodes this install location ($HOME/.opencode/bin).
OPENCODE_BIN="$HOME/.opencode/bin/opencode"
INSTALLER_URL="${OPENCODE_INSTALLER_URL:-https://opencode.ai/install}"
# Repo the installer downloads releases from; used here only to resolve the latest
# version tag via a redirect (the installer itself hardcodes the same repo).
OPENCODE_REPO="${OPENCODE_REPO:-anomalyco/opencode}"

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

# Resolve the latest opencode version WITHOUT hitting the rate-limited GitHub API.
#
# The upstream installer's "latest" path calls api.github.com to read the release
# tag, and that endpoint is limited to 60 unauthenticated requests/hour/IP. When
# that budget is exhausted (shared IP, VPN, prior `gh`/install-script use) the API
# returns an error with no tag_name, and the installer aborts with "Failed to fetch
# version information" — even though the binary download itself never needs the API.
#
# github.com/<repo>/releases/latest instead 302-redirects to .../releases/tag/vX.Y.Z.
# Reading that Location header is a plain web request, not subject to the API limit.
# Prints the bare version (e.g. 1.18.1) on success; prints nothing and returns
# non-zero on failure so the caller can fall back to the installer's own logic.
resolve_latest_version() {
    command -v curl >/dev/null 2>&1 || return 1
    local loc
    loc="$(curl -fsS -o /dev/null -w '%{redirect_url}' \
        "https://github.com/${OPENCODE_REPO}/releases/latest" 2>/dev/null)" || return 1
    case "$loc" in
        */releases/tag/v[0-9]*) printf '%s\n' "${loc##*/tag/v}" ;;
        *) return 1 ;;
    esac
}

# Run opencode's official installer non-interactively. It detects the platform,
# downloads the matching release binary, and lays it down at ~/.opencode/bin/opencode.
# --no-modify-path: don't touch shell rc files (this shim is already on PATH).
# We pass VERSION so the installer takes its pinned-version path (github.com only)
# and skips the fragile api.github.com version lookup: an explicit OPENCODE_VERSION
# if set, otherwise the latest version resolved via the redirect above. If neither
# is available we pass an empty VERSION and let the installer resolve it itself, so
# behaviour never regresses relative to a plain `curl | bash`.
# _OPENCODE_SHIM_BOOTSTRAPPING guards against the installer re-entering this shim.
bootstrap() {
    local tmp version
    tmp="$(mktemp)" || return 1
    trap "rm -f '$tmp'" RETURN
    if ! fetch_installer >"$tmp"; then
        return 1
    fi
    if [ ! -s "$tmp" ]; then
        echo "opencode: downloaded installer was empty." >&2
        return 1
    fi
    version="${OPENCODE_VERSION:-}"
    if [ -z "$version" ]; then
        version="$(resolve_latest_version || true)"
        [ -n "$version" ] && debug "resolved latest opencode version: $version"
    fi
    _OPENCODE_SHIM_BOOTSTRAPPING=1 VERSION="$version" bash "$tmp" --no-modify-path >&2
}

if [ ! -x "$OPENCODE_BIN" ]; then
    echo "opencode: first run — performing one-time opencode install into $HOME/.opencode ..." >&2
    if ! bootstrap; then
        echo "opencode: first-run installation failed." >&2
        echo "          Usually a transient network error or GitHub API rate limiting." >&2
        echo "          Re-run 'opencode', or pin a version to skip the version lookup:" >&2
        echo "              OPENCODE_VERSION=<x.y.z> opencode" >&2
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
