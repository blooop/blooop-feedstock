#!/usr/bin/env python3
"""
Update script for ralph-orchestrator package in the blooop-feedstock.

This script fetches the latest release from GitHub and updates the recipe
with new version and SHA256 checksums.
"""

import json
import re
import sys
import urllib.request
from pathlib import Path

GITHUB_REPO = "mikeyobrien/ralph-orchestrator"
RECIPE_PATH = Path("recipes/ralph-orchestrator/recipe.yaml")

# Mapping of platform conditions to release asset names
PLATFORM_ASSETS = {
    "linux and x86_64": "ralph-cli-x86_64-unknown-linux-gnu.tar.xz",
    "linux and aarch64": "ralph-cli-aarch64-unknown-linux-gnu.tar.xz",
    "osx and x86_64": "ralph-cli-x86_64-apple-darwin.tar.xz",
    "osx and arm64": "ralph-cli-aarch64-apple-darwin.tar.xz",
}


def get_latest_release(version_arg: str | None = None) -> tuple[str, dict[str, str]]:
    """Get latest release version and asset URLs from GitHub."""
    if version_arg:
        # Fetch specific version
        tag = f"v{version_arg}" if not version_arg.startswith("v") else version_arg
        api_url = f"https://api.github.com/repos/{GITHUB_REPO}/releases/tags/{tag}"
    else:
        # Fetch latest release
        api_url = f"https://api.github.com/repos/{GITHUB_REPO}/releases/latest"

    try:
        req = urllib.request.Request(api_url, headers={"Accept": "application/vnd.github.v3+json"})
        with urllib.request.urlopen(req) as response:
            release = json.loads(response.read().decode())
    except Exception as e:
        print(f"Failed to fetch release info: {e}")
        sys.exit(1)

    version = release["tag_name"].lstrip("v")
    assets = {asset["name"]: asset["browser_download_url"] for asset in release["assets"]}

    return version, assets


def get_sha256(url: str) -> str:
    """Fetch SHA256 checksum from .sha256 file."""
    sha_url = f"{url}.sha256"
    try:
        with urllib.request.urlopen(sha_url) as response:
            content = response.read().decode().strip()
            # Format is: "hash *filename" or "hash  filename"
            return content.split()[0]
    except Exception as e:
        print(f"Failed to fetch SHA256 from {sha_url}: {e}")
        sys.exit(1)


def update_recipe(version: str, checksums: dict[str, str]) -> None:
    """Update the recipe.yaml file with new version and checksums."""
    if not RECIPE_PATH.exists():
        print(f"Recipe file not found: {RECIPE_PATH}")
        sys.exit(1)

    recipe = RECIPE_PATH.read_text()

    # Check current version
    current_version_match = re.search(r'version: "([^"]+)"', recipe)
    current_version = current_version_match.group(1) if current_version_match else None

    # Update version in package section
    recipe = re.sub(r'version: "[^"]+"', f'version: "{version}"', recipe, count=1)

    # Update version in all source URLs
    recipe = re.sub(
        r'(https://github\.com/mikeyobrien/ralph-orchestrator/releases/download/v)[^/]+/',
        rf'\g<1>{version}/',
        recipe
    )

    # Update checksums for each platform
    # The format is:
    #   - if: linux and x86_64
    #     then:
    #       url: ...
    #       sha256: <checksum>
    for condition, sha256 in checksums.items():
        # Match sha256 line that follows a condition block
        # We look for the pattern: if: <condition>\n    then:\n      url: ...\n      sha256: <hash>
        pattern = rf'(if: {re.escape(condition)}\s+then:\s+url: [^\n]+\s+sha256: )[a-f0-9]+'
        recipe = re.sub(pattern, rf'\g<1>{sha256}', recipe)

    # Reset build number if version changed
    if current_version != version:
        recipe = re.sub(r'number: \d+', 'number: 0', recipe)
        print(f"Updated package version to {version} and reset build number to 0")
    else:
        print(f"Version {version} is already current, keeping existing build number")

    RECIPE_PATH.write_text(recipe)


def main():
    """Main function to update ralph-orchestrator recipe."""
    print("Updating ralph-orchestrator package...")

    # Get version from command line or fetch latest
    version_arg = sys.argv[1] if len(sys.argv) > 1 else None
    version, assets = get_latest_release(version_arg)
    print(f"Target version: {version}")

    # Fetch checksums for each platform
    checksums = {}
    for condition, asset_name in PLATFORM_ASSETS.items():
        if asset_name not in assets:
            print(f"Warning: Asset {asset_name} not found in release")
            continue

        print(f"Fetching checksum for {asset_name}...")
        sha256 = get_sha256(assets[asset_name])
        checksums[condition] = sha256
        print(f"  {sha256}")

    if not checksums:
        print("No checksums found, cannot update recipe")
        sys.exit(1)

    # Update the recipe
    update_recipe(version, checksums)

    print("ralph-orchestrator package update complete!")


if __name__ == "__main__":
    main()
