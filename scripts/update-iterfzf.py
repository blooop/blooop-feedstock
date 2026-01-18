#!/usr/bin/env python3
"""
Update script for iterfzf package in the blooop-feedstock.

This script monitors PyPI for new iterfzf releases and updates the recipe
with the latest version and checksums for all platform-specific wheels.
"""

import sys
import re
import json
from pathlib import Path
import urllib.request

PYPI_URL = "https://pypi.org/pypi/iterfzf/json"
RECIPE_PATH = Path("recipes/iterfzf/recipe.yaml")

# Map PyPI platform tags to conda platforms and wheel patterns
PLATFORM_MAP = {
    "linux-64": "manylinux_1_2_x86_64.manylinux_2_17_x86_64",
    "linux-aarch64": "manylinux_1_2_aarch64.manylinux_2_17_aarch64",
    "osx-64": "macosx_10_7_x86_64.macosx_10_9_x86_64",
    "osx-arm64": "macosx_11_0_arm64",
    "win-64": "win_amd64",
}


def get_latest_release():
    """Fetch the latest release information from PyPI."""
    try:
        with urllib.request.urlopen(PYPI_URL) as response:
            data = json.loads(response.read().decode())
            version = data["info"]["version"]
            urls = data["urls"]
            return version, urls
    except Exception as e:
        print(f"❌ Failed to fetch latest release: {e}")
        sys.exit(1)


def get_wheel_info(urls: list, platform_tag: str) -> tuple[str, str] | None:
    """Find the wheel URL and SHA256 for a specific platform tag."""
    for url_info in urls:
        if url_info["packagetype"] == "bdist_wheel":
            filename = url_info["filename"]
            if platform_tag in filename:
                return url_info["url"], url_info["digests"]["sha256"]
    return None


def update_recipe(version: str, urls: list) -> None:
    """Update the recipe.yaml file with new version and checksums."""
    if not RECIPE_PATH.exists():
        print(f"❌ Recipe file not found: {RECIPE_PATH}")
        sys.exit(1)

    recipe = RECIPE_PATH.read_text()

    # Get current version
    current_version_match = re.search(r'version: "([^"]+)"', recipe)
    current_version = current_version_match.group(1) if current_version_match else None

    # Update version in package section
    recipe = re.sub(r'(package:.*?version:\s*)"[^"]+"', f'\\1"{version}"', recipe, count=1, flags=re.DOTALL)

    # Update each platform's wheel URL and checksum
    selector_map = {
        "linux and x86_64": "linux-64",
        "linux and aarch64": "linux-aarch64",
        "osx and x86_64": "osx-64",
        "osx and arm64": "osx-arm64",
        "win and x86_64": "win-64",
    }

    for selector, conda_platform in selector_map.items():
        platform_tag = PLATFORM_MAP.get(conda_platform)
        if not platform_tag:
            continue

        wheel_info = get_wheel_info(urls, platform_tag)
        if not wheel_info:
            print(f"  ⚠️  No wheel found for {conda_platform}")
            continue

        wheel_url, sha256 = wheel_info
        print(f"  ✅ Found wheel for {conda_platform}: {sha256[:16]}...")

        # Update URL line with this selector
        url_pattern = rf'(-\s*url:\s*)https://[^\s]+(\s*#\s*\[{re.escape(selector)}\])'
        url_replacement = rf'\g<1>{wheel_url}\g<2>'
        recipe = re.sub(url_pattern, url_replacement, recipe)

        # Update SHA256 line with this selector
        sha_pattern = rf'(sha256:\s*)[\da-f]{{64}}(\s*#\s*\[{re.escape(selector)}\])'
        sha_replacement = rf'\g<1>{sha256}\g<2>'
        recipe = re.sub(sha_pattern, sha_replacement, recipe)

    # Update version in build script wheel filenames
    if current_version:
        recipe = recipe.replace(f"iterfzf-{current_version}", f"iterfzf-{version}")

    # Reset build number if version changed
    if current_version != version:
        recipe = re.sub(r'number: \d+', 'number: 0', recipe)
        print(f"✅ Updated package version from {current_version} to {version}")
    else:
        print(f"✅ Version {version} is already current")

    RECIPE_PATH.write_text(recipe)


def main():
    """Main function to update iterfzf recipe."""
    print("🔄 Updating iterfzf package...")

    # Get version from command line or fetch latest
    if len(sys.argv) > 1:
        version = sys.argv[1]
        # Fetch URLs for specific version
        url = f"https://pypi.org/pypi/iterfzf/{version}/json"
        try:
            with urllib.request.urlopen(url) as response:
                data = json.loads(response.read().decode())
                urls = data["urls"]
        except Exception as e:
            print(f"❌ Failed to fetch version {version}: {e}")
            sys.exit(1)
    else:
        version, urls = get_latest_release()

    print(f"📦 Target version: {version}")

    # Update the recipe
    update_recipe(version, urls)

    print("🎉 iterfzf package update complete!")


if __name__ == "__main__":
    main()
