#!/bin/bash
# build-and-upload.sh - Build and upload with automatic build number increment on conflicts
set -euo pipefail

PACKAGE="${1:?Usage: $0 <package> <platform> [channel]}"
PLATFORM="${2:?Usage: $0 <package> <platform> [channel]}"
CHANNEL="${3:-blooop}"
MAX_RETRIES=5

RECIPE_PATH="recipes/${PACKAGE}/recipe.yaml"

if [ ! -f "$RECIPE_PATH" ]; then
    echo "❌ Recipe not found: $RECIPE_PATH"
    exit 1
fi

get_current_build_number() {
    grep -m1 'number:' "$RECIPE_PATH" | sed 's/.*number: \([0-9]*\).*/\1/'
}

increment_build_number() {
    local current
    current=$(get_current_build_number)
    local new=$((current + 1))

    echo "🔄 Incrementing build number: $current → $new"
    sed -i "s/number: $current/number: $new/" "$RECIPE_PATH"
}

build_package() {
    echo "🏗️  Building ${PACKAGE} for ${PLATFORM}..."
    pixi run rattler-build build \
        --recipe "$RECIPE_PATH" \
        --target-platform "$PLATFORM" \
        --output-dir output \
        --channel conda-forge
}

upload_package() {
    local pkg_file="$1"
    local skip_flag="${2:-}"

    echo "📤 Uploading $(basename "$pkg_file") to ${CHANNEL}..."

    # Try trusted publishing first
    if pixi run rattler-build upload prefix --verbose $skip_flag --channel "$CHANNEL" "$pkg_file" 2>&1; then
        echo "✅ Upload succeeded via trusted publishing"
        return 0
    fi

    # Fallback to PIXI_TOKEN
    if [ -n "${PIXI_TOKEN:-}" ]; then
        echo "🔑 Retrying with PIXI_TOKEN..."
        if pixi run rattler-build upload prefix --verbose $skip_flag --channel "$CHANNEL" --api-key "$PIXI_TOKEN" "$pkg_file" 2>&1; then
            echo "✅ Upload succeeded with PIXI_TOKEN"
            return 0
        fi
    fi

    return 1
}

# Main loop with retry logic
for attempt in $(seq 1 $MAX_RETRIES); do
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Attempt $attempt of $MAX_RETRIES (build number: $(get_current_build_number))"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Build the package
    if ! build_package; then
        echo "❌ Build failed"
        exit 1
    fi

    # Find the newly built package
    PKG_FILE=$(find "output/${PLATFORM}" -name "${PACKAGE}-*.conda" -o -name "${PACKAGE}-*.tar.bz2" | sort | tail -n1)

    if [ -z "$PKG_FILE" ]; then
        echo "❌ No package file found after build"
        exit 1
    fi

    echo "📦 Built package: $(basename "$PKG_FILE")"

    # Try uploading (without --skip-existing to force overwrite)
    if upload_output=$(upload_package "$PKG_FILE" "" 2>&1); then
        echo "$upload_output"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✅ SUCCESS: Package uploaded successfully!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        exit 0
    else
        echo "$upload_output"

        # Check if it's a 409 conflict
        if echo "$upload_output" | grep -q "409 Conflict"; then
            if [ $attempt -lt $MAX_RETRIES ]; then
                echo "⚠️  Conflict detected - package already exists"
                increment_build_number
                echo "🔄 Retrying with new build number..."
                sleep 2
                continue
            else
                echo "❌ Max retries reached. Unable to upload after $MAX_RETRIES attempts."
                exit 1
            fi
        else
            echo "❌ Upload failed with non-conflict error"
            exit 1
        fi
    fi
done

echo "❌ Failed to upload after $MAX_RETRIES attempts"
exit 1
