#!/bin/sh
# initializeCommand for blooop-feedstock. Runs on the HOST before the container
# is created; each step owns the host-side paths that devcontainer.json mounts.
set -e
dir=$(dirname "$0")
"$dir/claude-code/init-host.sh"
"$dir/x11/init-host.sh"
