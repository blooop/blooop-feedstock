#!/bin/bash
# cldr - Claude Code with dangerously-skip-permissions and resume
# Shortcut for: claude --dangerously-skip-permissions --resume

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "$SCRIPT_DIR/claude" --dangerously-skip-permissions --resume "$@"
