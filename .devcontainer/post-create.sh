#!/usr/bin/env bash
# postCreateCommand for blooop-feedstock.
#
# In a script rather than inline in devcontainer.json because a one-line string
# in the JSON is a permanent merge-conflict surface, and because the steps below
# have to be able to fail loudly with a line number.
set -euo pipefail

# 1. The .pixi volume is created by docker, owned by root. Without this every
#    `pixi run` in the checkout dies with EACCES, and the error names a path
#    inside .pixi rather than the ownership, so it reads as a broken lock file.
sudo chown vscode .pixi

# 2. Seed known_hosts for the forge this clone actually uses.
#
# devpod forwards an ssh agent, so auth works without the host's ~/.ssh being
# mounted -- but host identity does not come with it. Without a known_hosts
# entry the first git operation over an ssh remote fails with "Host key
# verification failed": an interactive user gets a yes/no prompt, anything
# non-interactive just dies.
host=$(git config --get remote.origin.url 2>/dev/null |
    sed -nE 's#^(ssh://)?git@([^:/]+).*#\2#p') || true
if [ -n "${host:-}" ]; then
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    touch ~/.ssh/known_hosts && chmod 600 ~/.ssh/known_hosts
    if ! ssh-keygen -F "$host" >/dev/null 2>&1; then
        if scanned=$(ssh-keyscan -T 10 -t rsa,ecdsa,ed25519 "$host" 2>/dev/null) &&
           [ -n "$scanned" ]; then
            printf '%s\n' "$scanned" >> ~/.ssh/known_hosts
            sort -u -o ~/.ssh/known_hosts ~/.ssh/known_hosts
            echo "post-create: seeded known_hosts for $host"
        else
            # Non-fatal: no network at postCreate must not fail container creation.
            echo "post-create: could not reach $host, skipping known_hosts" >&2
        fi
    fi
fi

# 3. The environment itself.
#
# --frozen, not --locked. The lock file in this repo is rewritten by the nightly
# release workflow, so a branch cut before that run has a pixi.lock that is
# behind pixi.toml through no fault of the person opening the container.
# --locked turns that into a failed container create; --frozen installs the lock
# as it stands, which is the reproducible thing to do and leaves fixing the
# drift to `pixi install` when someone actually wants it fixed.
pixi install --frozen

# 4. A display for GUI apps (the palanteer viewer, kitty-bin, uhk-agent).
#
# devcontainer.json forwards the host's X socket and cookie; x11/display.sh,
# sourced by every shell, checks that the forward answers and otherwise starts a
# private Xvfb. Both paths need the packages below: Xvfb for the fallback,
# xdpyinfo (x11-utils) for the check, and Mesa, because conda's libGL is only the
# glvnd dispatcher and loads the vendor library from the system.
#
# Non-fatal, like the known_hosts step: no network at postCreate must not fail
# the container create. Without the packages display.sh does nothing at all.
if sudo apt-get update -qq >/dev/null 2>&1 &&
   sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
       xvfb x11-utils xauth libgl1-mesa-dri libglx-mesa0 libegl-mesa0 >/dev/null 2>&1; then
    echo "post-create: installed X11 display packages"
else
    echo "post-create: could not install X11 display packages, no display in this container" >&2
fi

# Hook display.sh into every shell kind: login shells (bash -l, which is also how
# `dl <ws> -- <cmd>` runs), interactive bash, and interactive zsh. The hook
# sources the script from the checkout, so an edit to it applies to the next shell.
hook="[ -r '$PWD/.devcontainer/x11/display.sh' ] && . '$PWD/.devcontainer/x11/display.sh'"
echo "$hook" | sudo tee /etc/profile.d/zz-x11-display.sh >/dev/null
for rc in /etc/bash.bashrc /etc/zsh/zshrc; do
    if [ -f "$rc" ] && ! grep -qF 'x11/display.sh' "$rc"; then
        echo "$hook" | sudo tee -a "$rc" >/dev/null
    fi
done
