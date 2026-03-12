#!/bin/bash
# Claude Code Shim - Downloads and executes the official Claude Code binary
# This shim does NOT redistribute the Claude Code binary, but downloads it on-demand
#
# Behavior:
# 1. If official Claude install exists (~/.local/bin/claude), defer to it
# 2. Otherwise, download and install to the conda/pixi environment

set -e

# Debug mode: set DEBUG_SHIM=1 to see diagnostic info
debug() {
    if [ "${DEBUG_SHIM:-}" = "1" ]; then
        echo "[DEBUG] $*" >&2
    fi
}

debug "Shim version: 0.5.0"
debug "HOME=$HOME"
debug "CONDA_PREFIX=${CONDA_PREFIX:-unset}"

# Check for existing official Claude installation first
# The official installer puts claude at ~/.local/bin/claude -> ~/.local/share/claude/
OFFICIAL_CLAUDE="$HOME/.local/bin/claude"
if [ -x "$OFFICIAL_CLAUDE" ] && [ -d "$HOME/.local/share/claude" ]; then
    exec "$OFFICIAL_CLAUDE" "$@"
fi

# GCS bucket URL for Claude Code releases
GCS_BUCKET="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

# Check if a directory is writable (or can be created)
is_writable_dir() {
    local dir="$1"
    if [ -d "$dir" ]; then
        # Directory exists, check if writable
        [ -w "$dir" ]
    else
        # Directory doesn't exist, check if parent is writable
        local parent
        parent=$(dirname "$dir")
        [ -d "$parent" ] && [ -w "$parent" ]
    fi
}

# Determine cache directory for the binary
# Priority: ~/.claude/cache (if ~/.claude exists and writable) > ~/.cache/claude-code (if ~/.cache exists and writable) > conda/pixi env
determine_install_dir() {
    local cache_dir

    # Check for ~/.claude directory (can be mounted in Docker)
    if [ -d "$HOME/.claude" ]; then
        cache_dir="$HOME/.claude/cache/claude-code"
        if is_writable_dir "$HOME/.claude/cache" || is_writable_dir "$HOME/.claude"; then
            debug "~/.claude exists and is writable, using it for cache"
            echo "$cache_dir"
            return
        fi
        debug "~/.claude exists but is not writable"
    else
        debug "~/.claude does not exist"
    fi

    # Check for ~/.cache directory (XDG standard, can be mounted in Docker)
    if [ -d "$HOME/.cache" ]; then
        cache_dir="$HOME/.cache/claude-code"
        if is_writable_dir "$cache_dir" || is_writable_dir "$HOME/.cache"; then
            debug "~/.cache exists and is writable, using it for cache"
            echo "$cache_dir"
            return
        fi
        debug "~/.cache exists but is not writable"
    else
        debug "~/.cache does not exist"
    fi

    # Fall back to conda/pixi environment directory
    debug "Falling back to conda/pixi env directory"
    echo "${CONDA_PREFIX:-${PREFIX:-$HOME/.pixi/envs/default}}/opt/claude-code"
}

# Run a command with a timeout (portable: Linux timeout, macOS perl fallback)
run_with_timeout() {
    local seconds="$1"
    shift
    if command -v timeout &> /dev/null; then
        timeout "$seconds" "$@"
    else
        # macOS/BSD fallback using perl alarm
        perl -e 'alarm shift; exec @ARGV' "$seconds" "$@"
    fi
}

# Validate that a Claude binary works correctly
# Returns 0 if valid, 1 if invalid/corrupted
validate_binary() {
    local binary="$1"

    # Check file exists and is executable
    if [ ! -x "$binary" ]; then
        debug "Binary not executable: $binary"
        return 1
    fi

    # Fast path: file too small to be a real binary (<1MB = likely corrupted)
    local file_size=0
    if command -v stat &> /dev/null; then
        # Try GNU stat first, then BSD stat
        file_size=$(stat -c %s "$binary" 2>/dev/null || stat -f %z "$binary" 2>/dev/null || echo "0")
    elif command -v wc &> /dev/null; then
        file_size=$(wc -c < "$binary" 2>/dev/null || echo "0")
    fi
    if [ "$file_size" -lt 1048576 ]; then
        debug "Binary too small (${file_size} bytes), likely corrupted"
        return 1
    fi

    # Run with --version (15s timeout) and check output contains "Claude Code"
    local version_output
    version_output=$(run_with_timeout 15 "$binary" --version 2>&1) || true

    if echo "$version_output" | grep -q "Claude Code"; then
        debug "Binary validation passed: $version_output"
        return 0
    else
        debug "Binary validation failed. Output: $version_output"
        return 1
    fi
}

# Installation directory for the real Claude Code binary
INSTALL_DIR="$(determine_install_dir)"
VERSION_FILE="$INSTALL_DIR/.version"
REAL_BINARY="$INSTALL_DIR/claude"

debug "INSTALL_DIR=$INSTALL_DIR"
debug "REAL_BINARY=$REAL_BINARY"
debug "Binary exists: $([ -f "$REAL_BINARY" ] && echo YES || echo NO)"

# Staging directory for background updates
STAGING_DIR="$INSTALL_DIR/.staging"
STAGING_BINARY="$STAGING_DIR/claude"
STAGING_VERSION="$STAGING_DIR/.version"
STAGING_COMPLETE="$STAGING_DIR/.complete"

# Version check throttle (seconds)
LAST_CHECK_FILE="$INSTALL_DIR/.last-check"
UPDATE_CHECK_INTERVAL=3600

# Detect platform
detect_platform() {
    local os arch platform

    case "$(uname -s)" in
        Darwin) os="darwin" ;;
        Linux) os="linux" ;;
        MINGW*|MSYS*|CYGWIN*) os="win32" ;;
        *) echo "unsupported"; return ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64) arch="x64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) echo "unsupported"; return ;;
    esac

    # Check for musl on Linux
    if [ "$os" = "linux" ]; then
        if [ -f /lib/libc.musl-x86_64.so.1 ] || [ -f /lib/libc.musl-aarch64.so.1 ] || ldd /bin/ls 2>&1 | grep -q musl; then
            platform="linux-${arch}-musl"
        else
            platform="linux-${arch}"
        fi
    else
        platform="${os}-${arch}"
    fi

    echo "$platform"
}

# Download function with timeout support
# Usage: download <url> <output> [max_time_seconds]
# max_time defaults to 30s for metadata, pass 600 for large binaries
download() {
    local url="$1"
    local output="$2"
    local max_time="${3:-30}"

    if command -v curl &> /dev/null; then
        if [ -n "$output" ]; then
            curl -fsSL --connect-timeout 10 --max-time "$max_time" -o "$output" "$url"
        else
            curl -fsSL --connect-timeout 10 --max-time "$max_time" "$url"
        fi
    elif command -v wget &> /dev/null; then
        if [ -n "$output" ]; then
            wget -q --connect-timeout=10 --read-timeout="$max_time" -O "$output" "$url"
        else
            wget -q --connect-timeout=10 --read-timeout="$max_time" -O - "$url"
        fi
    else
        echo "Error: Neither curl nor wget found" >&2
        return 1
    fi
}

# Download with progress bar for large foreground downloads
# Usage: download_large <url> <output> [max_time_seconds]
download_large() {
    local url="$1"
    local output="$2"
    local max_time="${3:-600}"

    if command -v curl &> /dev/null; then
        curl -fSL --connect-timeout 10 --max-time "$max_time" --progress-bar -o "$output" "$url"
    elif command -v wget &> /dev/null; then
        wget --connect-timeout=10 --read-timeout="$max_time" --show-progress -O "$output" "$url" 2>&1
    else
        echo "Error: Neither curl nor wget found" >&2
        return 1
    fi
}

# Retry wrapper for download functions
# Usage: download_with_retry <max_retries> <delay> <download_func> [args...]
download_with_retry() {
    local max_retries="$1"
    local delay="$2"
    local func="$3"
    shift 3

    local attempt=1
    while [ "$attempt" -le "$max_retries" ]; do
        if "$func" "$@"; then
            return 0
        fi
        if [ "$attempt" -lt "$max_retries" ]; then
            debug "Download attempt $attempt/$max_retries failed, retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))
        else
            debug "Download failed after $max_retries attempts"
        fi
        attempt=$((attempt + 1))
    done
    return 1
}

# Get installed version
get_installed_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    fi
}

# Get latest version from GCS (30s timeout, 3 retries)
get_latest_version() {
    download_with_retry 3 2 download "$GCS_BUCKET/stable" "" 30 2>/dev/null || echo ""
}

# Check if a staged update is ready to apply
apply_staged_update() {
    if [ -f "$STAGING_COMPLETE" ] && [ -f "$STAGING_BINARY" ]; then
        local staged_version
        staged_version=$(cat "$STAGING_VERSION" 2>/dev/null || echo "")
        if [ -z "$staged_version" ]; then
            debug "Staged update has no version file, cleaning up"
            rm -rf "$STAGING_DIR"
            return 1
        fi
        debug "Applying staged update: $staged_version"
        mkdir -p "$INSTALL_DIR"
        mv "$STAGING_BINARY" "$REAL_BINARY"
        chmod +x "$REAL_BINARY"
        echo "$staged_version" > "$VERSION_FILE"
        rm -rf "$STAGING_DIR"
        debug "Staged update applied successfully"
        return 0
    fi
    return 1
}

# Remove incomplete staging directory only if older than 15 minutes
# Avoids killing an actively running background download
clean_stale_staging() {
    if [ -d "$STAGING_DIR" ] && [ ! -f "$STAGING_COMPLETE" ]; then
        local dir_age_seconds=0
        local now
        now=$(date +%s)
        # GNU stat: -c %Y, BSD/macOS stat: -f %m
        local dir_mtime
        dir_mtime=$(stat -c %Y "$STAGING_DIR" 2>/dev/null || stat -f %m "$STAGING_DIR" 2>/dev/null || echo "0")
        if [ "$dir_mtime" -gt 0 ]; then
            dir_age_seconds=$((now - dir_mtime))
        fi
        if [ "$dir_age_seconds" -ge 900 ]; then
            debug "Cleaning stale staging directory (${dir_age_seconds}s old)"
            rm -rf "$STAGING_DIR"
        else
            debug "Staging directory exists but is recent (${dir_age_seconds}s old), leaving it"
        fi
    fi
}

# Check if enough time has passed since the last version check
should_check_version() {
    if [ ! -f "$LAST_CHECK_FILE" ]; then
        return 0
    fi
    local last_check_ts
    last_check_ts=$(head -n1 "$LAST_CHECK_FILE" 2>/dev/null || echo "0")
    local now
    now=$(date +%s)
    local elapsed=$(( now - last_check_ts ))
    debug "Time since last version check: ${elapsed}s (interval: ${UPDATE_CHECK_INTERVAL}s)"
    [ "$elapsed" -ge "$UPDATE_CHECK_INTERVAL" ]
}

# Read cached latest version from the last-check file
get_cached_latest_version() {
    if [ -f "$LAST_CHECK_FILE" ]; then
        sed -n '2p' "$LAST_CHECK_FILE" 2>/dev/null || echo ""
    fi
}

# Save version check result with timestamp
save_version_check() {
    local version="$1"
    mkdir -p "$INSTALL_DIR"
    printf '%s\n%s\n' "$(date +%s)" "$version" > "$LAST_CHECK_FILE"
}

# Download update in background to staging directory
# Designed to run as a detached subprocess
background_update() {
    local version="$1"
    local platform="$2"

    debug "Background update starting: v$version for $platform"

    # Create staging directory
    mkdir -p "$STAGING_DIR"

    # Download binary to staging (600s timeout, 2 retries)
    if ! download_with_retry 2 2 download "$GCS_BUCKET/$version/$platform/claude" "$STAGING_BINARY" 600; then
        debug "Background download failed"
        rm -rf "$STAGING_DIR"
        return 1
    fi

    # Verify checksum if possible
    local manifest_json expected_checksum actual_checksum
    manifest_json=$(download_with_retry 2 2 download "$GCS_BUCKET/$version/manifest.json" "" 30 2>/dev/null || echo "")

    if [ -n "$manifest_json" ]; then
        if command -v jq &> /dev/null; then
            expected_checksum=$(echo "$manifest_json" | jq -r ".platforms[\"$platform\"].checksum // empty")
        else
            local json_oneline
            json_oneline=$(echo "$manifest_json" | tr -d '\n\r\t ')
            local after_platform="${json_oneline#*\"$platform\"}"
            local after_checksum="${after_platform#*\"checksum\":\"}"
            expected_checksum="${after_checksum:0:64}"
            if ! echo "$expected_checksum" | grep -qE '^[a-f0-9]{64}$'; then
                expected_checksum=""
            fi
        fi

        if [ -n "$expected_checksum" ]; then
            if command -v sha256sum &> /dev/null; then
                actual_checksum=$(sha256sum "$STAGING_BINARY" | cut -d' ' -f1)
            elif command -v shasum &> /dev/null; then
                actual_checksum=$(shasum -a 256 "$STAGING_BINARY" | cut -d' ' -f1)
            fi

            if [ -n "$actual_checksum" ] && [ "$actual_checksum" != "$expected_checksum" ]; then
                debug "Background download checksum mismatch"
                rm -rf "$STAGING_DIR"
                return 1
            fi
        fi
    fi

    chmod +x "$STAGING_BINARY"
    echo "$version" > "$STAGING_VERSION"

    # Write sentinel last -- signals the download is complete and valid
    touch "$STAGING_COMPLETE"
    debug "Background update staged successfully: v$version"
}

# Install Claude Code binary
install_claude_code() {
    local version="$1"
    local platform="$2"
    local is_update="$3"

    if [ "$is_update" != "true" ]; then
        echo "First run: Setting up Claude Code..."
        echo "This one-time download will fetch the official binary."
        echo ""
    fi

    echo "Downloading Claude Code v${version} for ${platform}..."

    # Create temporary file for download
    local tmp_binary
    tmp_binary=$(mktemp)
    trap "rm -f '$tmp_binary'" EXIT

    # Download the binary (600s timeout, 3 retries, with progress bar)
    if ! download_with_retry 3 2 download_large "$GCS_BUCKET/$version/$platform/claude" "$tmp_binary" 600; then
        echo "Download failed. Please check your internet connection." >&2
        exit 1
    fi

    # Verify checksum if jq is available
    local manifest_json expected_checksum actual_checksum
    manifest_json=$(download_with_retry 2 2 download "$GCS_BUCKET/$version/manifest.json" "" 30 2>/dev/null || echo "")

    if [ -n "$manifest_json" ]; then
        if command -v jq &> /dev/null; then
            expected_checksum=$(echo "$manifest_json" | jq -r ".platforms[\"$platform\"].checksum // empty")
        else
            # Simple extraction without jq using bash string manipulation
            local json_oneline
            json_oneline=$(echo "$manifest_json" | tr -d '\n\r\t ')
            # Extract everything after the platform key, then after "checksum":"
            local after_platform="${json_oneline#*\"$platform\"}"
            local after_checksum="${after_platform#*\"checksum\":\"}"
            # Get first 64 characters (the checksum)
            expected_checksum="${after_checksum:0:64}"
            # Validate it looks like a checksum (64 hex chars)
            if ! echo "$expected_checksum" | grep -qE '^[a-f0-9]{64}$'; then
                expected_checksum=""
            fi
        fi

        if [ -n "$expected_checksum" ]; then
            if command -v sha256sum &> /dev/null; then
                actual_checksum=$(sha256sum "$tmp_binary" | cut -d' ' -f1)
            elif command -v shasum &> /dev/null; then
                actual_checksum=$(shasum -a 256 "$tmp_binary" | cut -d' ' -f1)
            fi

            if [ -n "$actual_checksum" ] && [ "$actual_checksum" != "$expected_checksum" ]; then
                echo "Checksum verification failed!" >&2
                echo "Expected: $expected_checksum" >&2
                echo "Actual:   $actual_checksum" >&2
                exit 1
            fi
        fi
    fi

    # Create installation directory
    mkdir -p "$INSTALL_DIR"

    # Move binary to installation directory
    mv "$tmp_binary" "$REAL_BINARY"
    chmod +x "$REAL_BINARY"
    trap - EXIT  # Clear trap since we moved the file

    # Save version info
    echo "$version" > "$VERSION_FILE"

    echo "Claude Code v${version} installed successfully!"
    echo ""
}

# Concurrency lock to prevent parallel installs from corrupting each other
LOCKFILE="$INSTALL_DIR/.lock"

acquire_lock() {
    mkdir -p "$INSTALL_DIR"
    # Use noclobber for portable atomic file creation
    if (set -C; echo $$ > "$LOCKFILE") 2>/dev/null; then
        debug "Lock acquired (pid $$)"
        return 0
    fi
    # Check if the lock holder is still alive
    local lock_pid
    lock_pid=$(cat "$LOCKFILE" 2>/dev/null || echo "")
    if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
        debug "Lock held by active process $lock_pid, waiting..."
        # Wait up to 120s for the other process to finish
        local waited=0
        while [ "$waited" -lt 120 ] && kill -0 "$lock_pid" 2>/dev/null; do
            sleep 2
            waited=$((waited + 2))
        done
        if kill -0 "$lock_pid" 2>/dev/null; then
            debug "Lock holder $lock_pid still running after ${waited}s, giving up"
            return 1
        fi
    fi
    # Stale lock from a dead process — reclaim it
    debug "Removing stale lock (pid ${lock_pid:-unknown})"
    rm -f "$LOCKFILE"
    if (set -C; echo $$ > "$LOCKFILE") 2>/dev/null; then
        debug "Lock acquired after stale cleanup (pid $$)"
        return 0
    fi
    return 1
}

release_lock() {
    rm -f "$LOCKFILE"
    debug "Lock released"
}

# Main logic
PLATFORM=$(detect_platform)
if [ "$PLATFORM" = "unsupported" ]; then
    echo "Error: Unsupported platform $(uname -s)/$(uname -m)" >&2
    exit 1
fi

# Step 1: Apply any staged update (fast mv, no network)
if apply_staged_update; then
    debug "Staged update applied, running updated binary"
fi

# Step 2: Clean incomplete staging from crashed/killed background downloads
clean_stale_staging

# Step 3: Determine what to do
if [ ! -f "$REAL_BINARY" ]; then
    # Case A: No binary -- synchronous install (first run)
    debug "Binary not found, need fresh install"
    if ! acquire_lock; then
        # Another process is installing — wait and check if binary appeared
        if [ -f "$REAL_BINARY" ]; then
            debug "Binary appeared after waiting for lock, proceeding"
        else
            echo "Error: Another installation is in progress. Please try again." >&2
            exit 1
        fi
    else
        trap 'release_lock' EXIT
        # Re-check after acquiring lock (another process may have finished)
        if [ ! -f "$REAL_BINARY" ]; then
            LATEST_VERSION=$(get_latest_version)
            if [ -z "$LATEST_VERSION" ]; then
                echo "Error: Cannot fetch latest version and no local installation found." >&2
                release_lock
                exit 1
            fi
            save_version_check "$LATEST_VERSION"
            install_claude_code "$LATEST_VERSION" "$PLATFORM" "false"
        fi
        release_lock
        trap - EXIT
    fi
elif ! validate_binary "$REAL_BINARY"; then
    # Case B: Corrupted binary -- synchronous repair
    echo "Cached binary appears corrupted, will re-download..."
    if ! acquire_lock; then
        if [ -f "$REAL_BINARY" ] && validate_binary "$REAL_BINARY"; then
            debug "Binary was repaired by another process"
        else
            echo "Error: Another installation is in progress. Please try again." >&2
            exit 1
        fi
    else
        trap 'release_lock' EXIT
        rm -f "$REAL_BINARY" "$VERSION_FILE"
        LATEST_VERSION=$(get_latest_version)
        if [ -z "$LATEST_VERSION" ]; then
            echo "Error: Cannot fetch latest version and no local installation found." >&2
            release_lock
            exit 1
        fi
        save_version_check "$LATEST_VERSION"
        install_claude_code "$LATEST_VERSION" "$PLATFORM" "true"
        release_lock
        trap - EXIT
    fi
else
    # Case C: Valid binary -- check for updates in background
    INSTALLED_VERSION=$(get_installed_version)
    if should_check_version; then
        debug "Checking for updates..."
        LATEST_VERSION=$(get_latest_version)
        if [ -n "$LATEST_VERSION" ]; then
            save_version_check "$LATEST_VERSION"
            if [ "$LATEST_VERSION" != "$INSTALLED_VERSION" ]; then
                debug "Update available: ${INSTALLED_VERSION:-unknown} -> $LATEST_VERSION (downloading in background)"
                background_update "$LATEST_VERSION" "$PLATFORM" </dev/null >/dev/null 2>&1 &
                disown
            else
                debug "Already up to date: $INSTALLED_VERSION"
            fi
        else
            debug "Could not fetch latest version, skipping update check"
        fi
    else
        debug "Skipping version check (throttled)"
    fi
fi

# Execute the real Claude Code binary with all arguments
exec "$REAL_BINARY" "$@"
