# Sourced by every shell in the container (post-create.sh hooks it into
# /etc/profile.d, /etc/bash.bashrc and /etc/zsh/zshrc). Picks a working display:
#
#   1. the host's X server, through the socket mounted at /mnt/host-x11, else
#   2. a private Xvfb on :99, started by the first shell that needs it.
#
# It never leaves DISPLAY pointing at a display that does not answer, and it
# says so whenever it falls back: a GUI app "opening" on the virtual display
# puts nothing on your screen, which is otherwise indistinguishable from a hang.
#
# The host directory is mounted at /mnt/host-x11, not over /tmp/.X11-unix, for
# two reasons:
#   - the docker-in-docker feature's entrypoint mounts a fresh tmpfs over /tmp
#     at start, which hides any bind mount under /tmp;
#   - the fallback Xvfb would otherwise make its socket in the host's directory,
#     where every other workspace on the machine would see -- and could take
#     over -- :99.

if [ -z "${__x11_display_done:-}" ] && command -v xdpyinfo >/dev/null 2>&1; then
    __x11_display_done=1

    # Expose the host socket where X clients look for it: /tmp/.X11-unix/X<n>.
    [ -d /tmp/.X11-unix ] || mkdir -m 1777 /tmp/.X11-unix 2>/dev/null
    case "${DISPLAY:-}" in
        :*)
            __x11_n=${DISPLAY#:}
            __x11_n=${__x11_n%%.*}
            if [ -S "/mnt/host-x11/X$__x11_n" ]; then
                ln -sfn "/mnt/host-x11/X$__x11_n" "/tmp/.X11-unix/X$__x11_n" 2>/dev/null
            fi
            ;;
    esac

    if [ -n "${DISPLAY:-}" ] && xdpyinfo >/dev/null 2>&1; then
        :   # the host display answers: use it
    else
        if [ -n "${DISPLAY:-}" ]; then
            __x11_why="host display '$DISPLAY' does not answer"
        else
            __x11_why="no host display"
        fi
        export DISPLAY=:99
        if ! xdpyinfo >/dev/null 2>&1; then
            # setsid: the server must outlive the shell that happened to start it.
            (setsid Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp >/tmp/xvfb-99.log 2>&1 &)
            __x11_i=0
            while [ "$__x11_i" -lt 50 ] && ! xdpyinfo >/dev/null 2>&1; do
                sleep 0.1
                __x11_i=$((__x11_i + 1))
            done
        fi
        case $- in
            *i*) echo "x11: $__x11_why; using Xvfb on :99 (a virtual display: no window on your screen)" >&2 ;;
        esac
    fi
    unset __x11_n __x11_why __x11_i
fi
