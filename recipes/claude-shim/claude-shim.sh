#!/bin/bash
# Claude Code Shim v0.6.2 - Ensures Claude Code is installed, then runs it
#
# Install hierarchy:
#   1. Official install at ~/.local/bin/claude (fast path)
#   2. Persistent cache at ~/.claude/cache/claude-code/claude (survives container restarts)
#   3. Legacy 0.5.0 caches at ~/.cache/claude-code or $CONDA_PREFIX/opt/claude-code
#   4. Fresh install via official installer
#
# After any successful install, a copy is cached in ~/.claude/cache/claude-code/
# so devcontainers with volume-mounted ~/.claude don't re-download on restart.
# Claude Code handles its own auto-updates after installation.

set -e

debug() {
    [ "${DEBUG_SHIM:-}" = "1" ] && echo "[DEBUG] $*" >&2
    return 0
}

CLAUDE="$HOME/.local/bin/claude"
CACHE_DIR="$HOME/.claude/cache/claude-code"

debug "Shim version: 0.6.2"
debug "HOME=$HOME"
debug "CLAUDE=$CLAUDE"
debug "CACHE_DIR=$CACHE_DIR"

# Fast path: official install exists
if [ -x "$CLAUDE" ]; then
    debug "Fast path: official install found"
    exec "$CLAUDE" "$@"
fi

# Cache restore: official install gone but persistent cache exists.
# Handles devcontainer/Docker restarts where ~/.local/bin is ephemeral
# but ~/.claude is volume-mounted.
if [ -x "$CACHE_DIR/claude" ]; then
    debug "Restoring from persistent cache"
    mkdir -p "$(dirname "$CLAUDE")"
    cp "$CACHE_DIR/claude" "$CLAUDE"
    chmod +x "$CLAUDE"
    exec "$CLAUDE" "$@"
fi

# Legacy 0.5.0 cache locations (migration path — remove in 0.7.0)
LEGACY_CLAUDE=""
for dir in \
    "$HOME/.cache/claude-code" \
    "${CONDA_PREFIX:+$CONDA_PREFIX/opt/claude-code}"; do
    [ -n "$dir" ] && [ -x "$dir/claude" ] && LEGACY_CLAUDE="$dir/claude" && break
done

# Atomic lock using mkdir (prevents concurrent installs)
LOCKFILE="${TMPDIR:-/tmp}/claude-shim-install.lock"

# Cache the installed binary for container persistence
cache_binary() {
    if [ -x "$CLAUDE" ]; then
        debug "Caching binary to $CACHE_DIR"
        mkdir -p "$CACHE_DIR"
        cp "$CLAUDE" "$CACHE_DIR/claude"
        chmod +x "$CACHE_DIR/claude"
    fi
}

run_install() {
    if mkdir "$LOCKFILE" 2>/dev/null; then
        trap 'rmdir "$LOCKFILE" 2>/dev/null' EXIT
        curl -fsSL https://claude.ai/install.sh | bash
        # Cache for container persistence, then clean up old legacy locations
        if [ -x "$CLAUDE" ]; then
            cache_binary
            rm -rf "$HOME/.cache/claude-code"
            [ -n "${CONDA_PREFIX:-}" ] && rm -rf "$CONDA_PREFIX/opt/claude-code"
        fi
        rmdir "$LOCKFILE" 2>/dev/null
        trap - EXIT
        return 0
    fi
    return 1
}

if [ -n "$LEGACY_CLAUDE" ]; then
    # Found old 0.5.0 binary — use it now, install official in background
    debug "Legacy binary found at $LEGACY_CLAUDE, installing official in background"
    ( run_install ) >/dev/null 2>&1 &
    disown 2>/dev/null
    exec "$LEGACY_CLAUDE" "$@"
fi

# No binary anywhere — synchronous install
debug "No binary found, running synchronous install"
if run_install; then
    exec "$CLAUDE" "$@"
fi

# Another terminal is installing — wait for it
echo "Another terminal is installing Claude Code. Waiting..."
waited=0
while [ -d "$LOCKFILE" ] && [ "$waited" -lt 120 ]; do
    sleep 2
    waited=$((waited + 2))
done

if [ -x "$CLAUDE" ]; then
    exec "$CLAUDE" "$@"
fi

echo "Installation did not complete. Please try again." >&2
exit 1
