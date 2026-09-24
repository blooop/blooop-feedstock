#!/bin/sh
# Host side of the X11 forward. Runs on the HOST before the container is created.
#
# It has to succeed on a host with no X server at all -- a headless box, a CI
# runner -- so every path devcontainer.json bind-mounts for X11 is created here.
# A missing mount source fails the container create outright, and there is no
# way to mark a mount optional. Whether the forward actually works is decided
# later, inside the container, by display.sh.

# 1. The socket directory. On a desktop, systemd-tmpfiles already made it (root,
#    1777) and this is a no-op. On a host without X it becomes an empty
#    directory, so the mount has a source; 1777 is what an X server expects.
if [ ! -d /tmp/.X11-unix ]; then
    mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix
fi

# 2. A copy of the host's X cookie in a fixed place. The mount can not point at
#    $XAUTHORITY: that path differs per desktop and is unset on a headless host.
#    The file always exists, and is empty when there is no display to authorise.
#
#    The directory is mounted, not the file: the mv below replaces the inode, and
#    a single-file bind mount would keep showing the old one.
dir="$HOME/.cache/devcontainer-x11"
mkdir -p "$dir" && chmod 700 "$dir"
cookie="$dir/Xauthority"
(umask 077 && : > "$cookie.new")
if [ -n "${DISPLAY:-}" ] && command -v xauth >/dev/null 2>&1; then
    # ffff is FamilyWild. The container has its own hostname, so a cookie bound
    # to the host's name would never match there.
    xauth nlist "$DISPLAY" 2>/dev/null | sed -e 's/^..../ffff/' |
        xauth -q -f "$cookie.new" nmerge - 2>/dev/null || true
fi
mv -f "$cookie.new" "$cookie"
