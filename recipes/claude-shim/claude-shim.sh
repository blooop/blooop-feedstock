#!/bin/bash
# Claude Code Shim v0.6.1 - Ensures Claude Code is installed, then runs it
#
# If Claude is already installed (~/.local/bin/claude), runs it directly.
# If upgrading from 0.5.0, uses the legacy cached binary immediately while
# installing the official version in the background.
# Otherwise, installs via the official installer and then runs it.
# Claude Code handles its own auto-updates after installation.

set -e

CLAUDE="$HOME/.local/bin/claude"

# Fast path: official install exists
if [ -x "$CLAUDE" ]; then
    exec "$CLAUDE" "$@"
fi

# Legacy 0.5.0 cache locations (migration path — remove in 0.7.0)
LEGACY_CLAUDE=""
for dir in \
    "$HOME/.claude/cache/claude-code" \
    "$HOME/.cache/claude-code" \
    "${CONDA_PREFIX:+$CONDA_PREFIX/opt/claude-code}"; do
    [ -n "$dir" ] && [ -x "$dir/claude" ] && LEGACY_CLAUDE="$dir/claude" && break
done

# Atomic lock using mkdir (prevents concurrent installs)
LOCKFILE="${TMPDIR:-/tmp}/claude-shim-install.lock"

run_install() {
    if mkdir "$LOCKFILE" 2>/dev/null; then
        trap 'rmdir "$LOCKFILE" 2>/dev/null' EXIT
        curl -fsSL https://claude.ai/install.sh | bash
        # Clean up legacy caches after successful official install
        if [ -x "$CLAUDE" ]; then
            rm -rf "$HOME/.claude/cache/claude-code" "$HOME/.cache/claude-code"
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
    ( run_install ) >/dev/null 2>&1 &
    disown 2>/dev/null
    exec "$LEGACY_CLAUDE" "$@"
fi

# No binary anywhere — synchronous install
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
