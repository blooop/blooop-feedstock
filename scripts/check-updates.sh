#!/bin/bash

# check-updates.sh - Check all packages for available updates
# This script checks each package recipe against its upstream source
# and reports which packages have updates available

set -e

echo "🔍 Checking all packages for updates..."
echo "=================================="

UPDATES_FOUND=0
TOTAL_PACKAGES=0

# Function to check a specific package
check_package() {
    local package_name=$1
    local recipe_dir="recipes/$package_name"
    
    if [ ! -d "$recipe_dir" ]; then
        echo "⚠️  Package directory not found: $recipe_dir"
        return 1
    fi
    
    if [ ! -f "$recipe_dir/recipe.yaml" ]; then
        echo "⚠️  Recipe not found: $recipe_dir/recipe.yaml"
        return 1
    fi
    
    echo "📦 Checking $package_name..."
    TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
    
    # Get current version from recipe (look for the package version, not schema_version)
    local current_version=$(grep -A 3 'package:' "$recipe_dir/recipe.yaml" | grep 'version:' | sed 's/.*version:[[:space:]]*"\([^"]*\)".*/\1/')
    
    if [ -z "$current_version" ]; then
        echo "   ⚠️  Could not parse current version from recipe.yaml"
        echo "   Debug: $(grep -A 3 'package:' "$recipe_dir/recipe.yaml" | grep 'version:')"
        return 1
    fi
    
    echo "   Current version: $current_version"
    
    # Package-specific update checking
    case $package_name in
        "claude-shim")
            # claude-shim is versioned independently - no upstream to check
            echo "   ✅ claude-shim is versioned independently (no upstream version to check)"
            ;;
        "uhk-agent")
            check_github_release "UltimateHackingKeyboard/agent" "$current_version"
            ;;
        "codex")
            # codex ships as a bootstrap shim that installs latest Codex on first
            # run and self-updates thereafter - no upstream version to track here
            echo "   ✅ codex is a self-updating bootstrap shim (no upstream version to check)"
            ;;
        *)
            echo "   ⚠️  No update checker implemented for $package_name"
            ;;
    esac
}

# Generic GitHub release version checker
check_github_release() {
    local repo=$1
    local current_version=$2

    local latest_version=$(curl -s "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null | grep -m1 '"tag_name"' | sed 's/.*"tag_name": "v\([^"]*\)".*/\1/')

    if [ -z "$latest_version" ]; then
        echo "   ❌ Failed to fetch latest version from $repo"
        return 1
    fi

    echo "   Latest version: $latest_version"

    if [ "$current_version" != "$latest_version" ]; then
        echo "   🆕 UPDATE AVAILABLE: $current_version → $latest_version"
        UPDATES_FOUND=$((UPDATES_FOUND + 1))
    else
        echo "   ✅ Up to date"
    fi
}

# Main execution
echo "Scanning recipes directory..."

if [ ! -d "recipes" ]; then
    echo "❌ recipes directory not found. Are you in the feedstock root?"
    exit 1
fi

# Check if specific package was requested
if [ $# -eq 1 ]; then
    check_package "$1"
else
    # Check all packages in recipes directory
    for recipe_dir in recipes/*/; do
        if [ -d "$recipe_dir" ]; then
            package_name=$(basename "$recipe_dir")
            check_package "$package_name"
            echo ""
        fi
    done
fi

echo "=================================="
echo "📊 Summary:"
echo "   Packages checked: $TOTAL_PACKAGES"
echo "   Updates available: $UPDATES_FOUND"

if [ $UPDATES_FOUND -gt 0 ]; then
    echo ""
    echo "🔄 To update all packages with available updates:"
    echo "   Run the GitHub Action manually or wait for the scheduled run"
    echo "   Or update individual packages using the commands shown above"
    exit 1  # Exit with error code to indicate updates are available
else
    echo "   ✅ All packages are up to date!"
    exit 0
fi