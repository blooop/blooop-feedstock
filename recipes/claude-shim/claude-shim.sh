#!/bin/bash
# Claude Code Shim - Ensures Claude Code is installed, then runs it
#
# If Claude is already installed (~/.local/bin/claude), runs it directly.
# Otherwise, installs via the official installer and then runs it.
# Claude Code handles its own auto-updates after installation.

set -e

# If official Claude install exists, use it
CLAUDE="$HOME/.local/bin/claude"
if [ -x "$CLAUDE" ]; then
    exec "$CLAUDE" "$@"
fi

# Install Claude Code via official installer
echo "Claude Code not found. Installing..."
curl -fsSL https://claude.ai/install.sh | bash

# Run it
exec "$CLAUDE" "$@"
