#!/bin/bash
# Codex bootstrap shim
#
# Installed by the `codex` conda package as $PREFIX/bin/codex. This shim does NOT
# redistribute Codex. On first run it performs OpenAI's official "standalone"
# install into ~/.codex (byte-for-byte the same thing `curl | sh` produces), then
# execs the resulting binary.
#
# Why a shim instead of packaging the binary directly: Codex has install-method
# awareness (`codex update`, `codex doctor`, ...). A binary dropped into a conda
# prefix is not recognized and `codex update` fails with "Could not detect the
# installation method". By bootstrapping the real standalone install, every native
# feature works and Codex manages its own updates inside ~/.codex — this package
# never has to be re-published for a new Codex release.
#
# Env:
#   CODEX_HOME           install root (default ~/.codex) — respected by Codex too
#   CODEX_RELEASE        pin a version for the first-run install (else latest)
#   CODEX_INSTALLER_URL  override the installer URL (default: OpenAI's)
#   DEBUG_SHIM=1         verbose diagnostics on stderr

debug() {
    if [ "${DEBUG_SHIM:-}" = "1" ]; then
        echo "[codex-shim] $*" >&2
    fi
}

CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
STANDALONE_CURRENT="$CODEX_HOME_DIR/packages/standalone/current"
INSTALLER_URL="${CODEX_INSTALLER_URL:-https://chatgpt.com/codex/install.sh}"

debug "CODEX_HOME_DIR=$CODEX_HOME_DIR"
debug "STANDALONE_CURRENT=$STANDALONE_CURRENT"

# Print the path to the real standalone codex binary, if installed.
real_codex() {
    local c
    for c in "$STANDALONE_CURRENT/bin/codex" "$STANDALONE_CURRENT/codex"; do
        if [ -x "$c" ]; then
            printf '%s\n' "$c"
            return 0
        fi
    done
    return 1
}

fetch_installer() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$INSTALLER_URL"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$INSTALLER_URL"
    else
        echo "codex: curl or wget is required to install Codex on first run." >&2
        return 1
    fi
}

# Run OpenAI's official installer non-interactively. It lays down the standalone
# install under ~/.codex and a launcher at ~/.local/bin/codex. CODEX_RELEASE (if
# set in the environment) is honored by the installer for version pinning.
bootstrap() {
    local tmp
    tmp="$(mktemp)" || return 1
    trap "rm -f '$tmp'" RETURN
    if ! fetch_installer >"$tmp"; then
        return 1
    fi
    if [ ! -s "$tmp" ]; then
        echo "codex: downloaded installer was empty." >&2
        return 1
    fi
    CODEX_NON_INTERACTIVE=1 sh "$tmp" >&2
}

BIN="$(real_codex)" || BIN=""

if [ -z "$BIN" ]; then
    echo "codex: first run — performing one-time Codex install into $CODEX_HOME_DIR ..." >&2
    if ! bootstrap; then
        echo "codex: installation failed (network access is required on first run)." >&2
        echo "       See https://developers.openai.com/codex/cli/" >&2
        exit 1
    fi
    BIN="$(real_codex)" || BIN=""
    if [ -z "$BIN" ]; then
        echo "codex: installer completed but no runnable binary was found under" >&2
        echo "       $STANDALONE_CURRENT" >&2
        exit 1
    fi
fi

debug "exec $BIN $*"
exec "$BIN" "$@"
