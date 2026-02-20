#!/bin/bash
# Dune 3D Flatpak Shim - Installs and runs Dune 3D via Flatpak
#
# This shim does NOT redistribute Dune 3D. It installs via Flatpak on first run.
#
# Behavior:
# 1. If dune3d is already on PATH (e.g. system package), defer to it
# 2. Otherwise, ensure Flatpak is set up and install from Flathub
# 3. Run via flatpak run org.dune3d.dune3d

set -e

FLATPAK_APP_ID="org.dune3d.dune3d"
SHIM_VERSION="0.1.0"

# Debug mode: set DEBUG_SHIM=1 to see diagnostic info
debug() {
    if [ "${DEBUG_SHIM:-}" = "1" ]; then
        echo "[DEBUG] $*" >&2
    fi
}

debug "Shim version: $SHIM_VERSION"

# Check for existing system installation of dune3d (not this shim)
# Skip any candidates under ~/.pixi or $CONDA_PREFIX to avoid infinite loops
# with pixi trampolines that redirect back to this script.
for candidate in $(type -aP dune3d 2>/dev/null); do
    case "$candidate" in
        "$HOME/.pixi/"*|"${CONDA_PREFIX:-__none__}/"*) debug "Skipping pixi/conda path: $candidate" ;;
        *)
            debug "Found system dune3d at $candidate, deferring to it"
            exec "$candidate" "$@"
            ;;
    esac
done

# Handle --shim-version flag (info about the shim itself)
if [ "${1:-}" = "--shim-version" ]; then
    echo "dune3d-shim $SHIM_VERSION (Flatpak wrapper)"
    echo "Flatpak app: $FLATPAK_APP_ID"
    if command -v flatpak &>/dev/null && flatpak info "$FLATPAK_APP_ID" &>/dev/null; then
        echo "Installed version: $(flatpak info "$FLATPAK_APP_ID" --show-version 2>/dev/null || echo 'unknown')"
    else
        echo "Status: not yet installed"
    fi
    exit 0
fi

# Verify flatpak is available
if ! command -v flatpak &>/dev/null; then
    echo "Error: flatpak is not installed." >&2
    echo "" >&2
    echo "Install flatpak for your distribution:" >&2
    echo "  Ubuntu/Debian: sudo apt install flatpak" >&2
    echo "  Fedora:        sudo dnf install flatpak" >&2
    echo "  Arch:          sudo pacman -S flatpak" >&2
    echo "" >&2
    echo "Then re-run this command." >&2
    exit 1
fi

# Ensure Flathub remote is configured
if ! flatpak remotes --columns=name 2>/dev/null | grep -q "^flathub$"; then
    echo "Adding Flathub repository..."
    flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

# Install Dune 3D if not already installed
if ! flatpak info "$FLATPAK_APP_ID" &>/dev/null; then
    echo "First run: Installing Dune 3D from Flathub..."
    echo "This one-time install will download the Flatpak package."
    echo ""
    if ! flatpak install --user -y flathub "$FLATPAK_APP_ID"; then
        echo "Error: Failed to install Dune 3D from Flathub." >&2
        echo "Check your internet connection and try again." >&2
        exit 1
    fi
    echo ""
    echo "Dune 3D installed successfully!"
    echo ""
fi

# Run Dune 3D via Flatpak
debug "Running: flatpak run $FLATPAK_APP_ID $*"
exec flatpak run "$FLATPAK_APP_ID" "$@"
