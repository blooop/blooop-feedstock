#!/usr/bin/env python3
"""
Update script for claude-code package in the blooop-feedstock.

This script updates the recipe version for the claude-code shim package.
The shim downloads the actual binary at runtime, so we only need to update
the package version.
"""

import sys
import re
from pathlib import Path
import urllib.request

BASE_URL = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"
RECIPE_PATH = Path("recipes/claude-code/recipe.yaml")

def get_version(version_arg: str | None = None) -> str:
    """Get Claude Code version - either from argument or fetch latest."""
    if version_arg:
        return version_arg

    try:
        with urllib.request.urlopen(f"{BASE_URL}/latest") as response:
            return response.read().decode().strip()
    except Exception as e:
        print(f"❌ Failed to fetch latest version: {e}")
        sys.exit(1)

def update_recipe(version: str) -> None:
    """Update the recipe.yaml file with new version."""
    if not RECIPE_PATH.exists():
        print(f"❌ Recipe file not found: {RECIPE_PATH}")
        sys.exit(1)

    recipe = RECIPE_PATH.read_text()

    # Check current version
    current_version_match = re.search(r'version: "([^"]+)"', recipe)
    current_version = current_version_match.group(1) if current_version_match else None

    # Update version
    recipe = re.sub(r'version: "[^"]+"', f'version: "{version}"', recipe, count=1)

    # Only reset build number if the version actually changed
    if current_version != version:
        recipe = re.sub(r'number: \d+', 'number: 0', recipe)
        print(f"✅ Updated package version to {version} and reset build number to 0")
    else:
        print(f"✅ Version {version} is already current, keeping existing build number")

    RECIPE_PATH.write_text(recipe)

def main():
    """Main function to update Claude Code recipe."""
    print("🔄 Updating Claude Code shim package...")

    # Get version from command line or fetch latest
    version = get_version(sys.argv[1] if len(sys.argv) > 1 else None)
    print(f"📦 Target version: {version}")

    # Update the recipe
    update_recipe(version)

    print("🎉 Claude Code shim package update complete!")
    print(f"   The shim will download Claude Code {version} on first run.")

if __name__ == "__main__":
    main()
