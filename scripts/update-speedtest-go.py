#!/usr/bin/env python3
"""
Update script for speedtest-go package in the blooop-feedstock.

This script monitors the showwin/speedtest-go GitHub repository for new releases
and updates the recipe with the latest version and checksums for all platforms.
"""

import sys
import re
import json
import hashlib
from pathlib import Path
import urllib.request

GITHUB_REPO = "showwin/speedtest-go"
GITHUB_API_URL = f"https://api.github.com/repos/{GITHUB_REPO}/releases/latest"
RECIPE_PATH = Path("recipes/speedtest-go/recipe.yaml")

# Platform -> the arch suffix used in the release asset name
# (assets are named speedtest-go_<version>_<suffix>.tar.gz)
PLATFORM_SUFFIXES = {
    "linux-64": "Linux_x86_64",
    "linux-aarch64": "Linux_arm64",
    "osx-64": "Darwin_x86_64",
    "osx-arm64": "Darwin_arm64",
    "win-64": "Windows_x86_64",
}


def get_latest_release():
    """Fetch the latest release information from GitHub API."""
    try:
        with urllib.request.urlopen(GITHUB_API_URL) as response:
            data = json.loads(response.read().decode())
            # speedtest-go tags are prefixed with "v" (e.g. "v1.7.11")
            version = data["tag_name"].lstrip("v")
            return version
    except Exception as e:
        print(f"Failed to fetch latest release: {e}")
        sys.exit(1)


def download_and_hash(url: str) -> str:
    """Download a file and return its SHA256 hash."""
    print(f"  Downloading {url.split('/')[-1]}...")
    try:
        with urllib.request.urlopen(url) as response:
            sha256_hash = hashlib.sha256(response.read()).hexdigest()
            print(f"  SHA256: {sha256_hash}")
            return sha256_hash
    except Exception as e:
        print(f"  Failed to download: {e}")
        return ""


def get_checksums(version: str) -> dict[str, str]:
    """Get SHA256 checksums for all platform archives."""
    base_url = f"https://github.com/{GITHUB_REPO}/releases/download/v{version}"
    checksums = {}

    print("Fetching checksums for all platforms...")
    for platform, suffix in PLATFORM_SUFFIXES.items():
        url = f"{base_url}/speedtest-go_{version}_{suffix}.tar.gz"
        checksums[platform] = download_and_hash(url)

    missing = [p for p, h in checksums.items() if not h]
    if missing:
        print(f"Failed to hash archives for: {', '.join(missing)}")
        sys.exit(1)

    return checksums


def update_recipe(version: str, checksums: dict[str, str]) -> None:
    """Update the recipe.yaml file with new version and checksums."""
    if not RECIPE_PATH.exists():
        print(f"Recipe file not found: {RECIPE_PATH}")
        sys.exit(1)

    recipe = RECIPE_PATH.read_text()

    current_version_match = re.search(r'version: "([^"]+)"', recipe)
    current_version = current_version_match.group(1) if current_version_match else None

    # Update version in package section
    recipe = re.sub(r'(package:.*?version:\s*)"[^"]+"', f'\\1"{version}"', recipe, count=1, flags=re.DOTALL)

    # Update version in the release URLs (tag has a v prefix, filename does not)
    if current_version:
        recipe = recipe.replace(
            f"/releases/download/v{current_version}/speedtest-go_{current_version}_",
            f"/releases/download/v{version}/speedtest-go_{version}_",
        )

    selector_map = {
        "linux and x86_64": "linux-64",
        "linux and aarch64": "linux-aarch64",
        "osx and x86_64": "osx-64",
        "osx and arm64": "osx-arm64",
        "win": "win-64",
    }

    for selector, platform in selector_map.items():
        pattern = rf'(sha256:\s*)[\da-f]{{64}}(\s*#\s*\[{re.escape(selector)}\])'
        recipe = re.sub(pattern, rf'\g<1>{checksums[platform]}\g<2>', recipe)
        print(f"  Updated checksum for {platform}")

    # Reset build number if version changed
    if current_version != version:
        recipe = re.sub(r'number: \d+', 'number: 0', recipe)
        print(f"Updated package version to {version} and reset build number to 0")
    else:
        print(f"Version {version} is already current, keeping existing build number")

    RECIPE_PATH.write_text(recipe)


def main():
    """Main function to update speedtest-go recipe."""
    print("Updating speedtest-go package...")

    version = sys.argv[1] if len(sys.argv) > 1 else get_latest_release()
    version = version.lstrip("v")
    print(f"Target version: {version}")

    checksums = get_checksums(version)
    update_recipe(version, checksums)

    print("speedtest-go package update complete!")


if __name__ == "__main__":
    main()
