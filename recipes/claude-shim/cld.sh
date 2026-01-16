#!/bin/bash
# cld - Claude Code with dangerously-skip-permissions
# Shortcut for: claude --dangerously-skip-permissions

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "$SCRIPT_DIR/claude" --dangerously-skip-permissions "$@"
