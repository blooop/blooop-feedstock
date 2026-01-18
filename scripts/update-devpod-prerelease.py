#!/usr/bin/env python3
"""
Update script for devpod-prerelease package in the blooop-feedstock.

This script monitors the skevetter/devpod GitHub repository for new PRE-RELEASE
versions and updates the recipe with the latest prerelease version and checksums.

Unlike update-devpod.py which tracks stable releases, this script specifically
looks for releases marked as prerelease: true in the GitHub API.
"""

import sys
import re
import json
import hashlib
from pathlib import Path
import urllib.request

GITHUB_REPO = "skevetter/devpod"
GITHUB_API_URL = f"https://api.github.com/repos/{GITHUB_REPO}/releases"
RECIPE_PATH = Path("recipes/devpod-prerelease/recipe.yaml")

# Platform-specific binary names
PLATFORM_BINARIES = {
    "linux-64": "devpod-linux-amd64",
    "linux-aarch64": "devpod-linux-arm64",
    "osx-64": "devpod-darwin-amd64",
    "osx-arm64": "devpod-darwin-arm64",
    "win-64": "devpod-windows-amd64.exe",
}


def get_latest_prerelease():
    """Fetch the latest prerelease information from GitHub API.

    Returns the latest prerelease that has assets available.
    If no prereleases with assets exist, returns None.
    """
    try:
        with urllib.request.urlopen(GITHUB_API_URL) as response:
            releases = json.loads(response.read().decode())

            # Find prereleases with assets
            for release in releases:
                if release.get("prerelease") and release.get("assets"):
                    version = release["tag_name"].lstrip("v")
                    assets = {asset["name"]: asset["browser_download_url"] for asset in release["assets"]}
                    print(f"Found prerelease v{version} with {len(assets)} assets")
                    return version, assets

            # No prerelease with assets found
            print("No prereleases with assets found")
            return None, None
    except Exception as e:
        print(f"Failed to fetch releases: {e}")
        sys.exit(1)


def get_latest_release_fallback():
    """Fetch the latest release (including prereleases) as fallback."""
    try:
        # Use the releases endpoint without /latest to get all releases
        with urllib.request.urlopen(GITHUB_API_URL) as response:
            releases = json.loads(response.read().decode())
            if releases:
                release = releases[0]  # Most recent release
                version = release["tag_name"].lstrip("v")
                assets = {asset["name"]: asset["browser_download_url"] for asset in release.get("assets", [])}
                is_prerelease = release.get("prerelease", False)
                print(f"Using latest release v{version} (prerelease={is_prerelease})")
                return version, assets
            return None, None
    except Exception as e:
        print(f"Failed to fetch releases: {e}")
        sys.exit(1)


def get_version(version_arg: str | None = None):
    """Get DevPod prerelease version - either from argument or fetch latest from GitHub."""
    if version_arg:
        return version_arg, None

    # First try to get a prerelease
    version, assets = get_latest_prerelease()
    if version and assets:
        return version, assets

    # Fallback to latest release if no prerelease with assets
    print("Falling back to latest release...")
    version, assets = get_latest_release_fallback()
    return version, assets


def download_and_hash(url: str) -> str:
    """Download a file and return its SHA256 hash."""
    print(f"  Downloading {url.split('/')[-1]}...")
    try:
        with urllib.request.urlopen(url) as response:
            data = response.read()
            sha256_hash = hashlib.sha256(data).hexdigest()
            print(f"  SHA256: {sha256_hash}")
            return sha256_hash
    except Exception as e:
        print(f"  Failed to download: {e}")
        return ""


def get_checksums(version: str, assets: dict | None = None) -> dict[str, str]:
    """Get SHA256 checksums for all platform binaries."""
    checksums = {}

    if assets is None:
        # Build URLs manually if assets not provided
        base_url = f"https://github.com/{GITHUB_REPO}/releases/download/v{version}"
        assets = {name: f"{base_url}/{name}" for name in PLATFORM_BINARIES.values()}

    print("Fetching checksums for all platforms...")

    for platform, binary_name in PLATFORM_BINARIES.items():
        if binary_name in assets:
            url = assets[binary_name]
            checksums[platform] = download_and_hash(url)
        else:
            print(f"  Binary not found for {platform}: {binary_name}")
            checksums[platform] = ""

    return checksums


def update_recipe(version: str, checksums: dict[str, str]) -> None:
    """Update the recipe.yaml file with new version and checksums.

    Note: Conda package versions cannot contain hyphens, so we convert them to underscores
    for the package version while keeping the original version for URLs.
    """
    if not RECIPE_PATH.exists():
        print(f"Recipe file not found: {RECIPE_PATH}")
        sys.exit(1)

    recipe = RECIPE_PATH.read_text()

    # Conda versions cannot contain hyphens - convert to underscores
    pkg_version = version.replace("-", "_")
    url_version = version  # Keep original for URLs

    # Check current package version (may have underscores)
    current_version_match = re.search(r'version: "([^"]+)"', recipe)
    current_pkg_version = current_version_match.group(1) if current_version_match else None
    # Convert back to URL format for matching old URLs
    current_url_version = current_pkg_version.replace("_", "-") if current_pkg_version else None

    # Update version in package section (with underscores for conda)
    recipe = re.sub(r'(package:.*?version:\s*)"[^"]+"', f'\\1"{pkg_version}"', recipe, count=1, flags=re.DOTALL)

    # Update version in all URLs (with original hyphens)
    if current_url_version:
        recipe = re.sub(
            rf'(https://github.com/{GITHUB_REPO}/releases/download/v){re.escape(current_url_version)}(/)',
            rf'\g<1>{url_version}\g<2>',
            recipe
        )

    # Update checksums for each platform
    selector_map = {
        "linux and x86_64": "linux-64",
        "linux and aarch64": "linux-aarch64",
        "osx and x86_64": "osx-64",
        "osx and arm64": "osx-arm64",
        "win": "win-64",
    }

    for selector, platform in selector_map.items():
        if platform in checksums and checksums[platform]:
            # Match sha256 line with specific selector
            pattern = rf'(sha256:\s*)[\da-f]{{64}}(\s*#\s*\[{re.escape(selector)}\])'
            replacement = rf'\g<1>{checksums[platform]}\g<2>'
            recipe = re.sub(pattern, replacement, recipe)
            print(f"  Updated checksum for {platform}")

    # Reset build number if version changed
    if current_pkg_version != pkg_version:
        recipe = re.sub(r'number: \d+', 'number: 0', recipe)
        print(f"Updated package version to {pkg_version} (from {url_version}) and reset build number to 0")
    else:
        print(f"Version {pkg_version} is already current, keeping existing build number")

    RECIPE_PATH.write_text(recipe)


def main():
    """Main function to update DevPod prerelease recipe."""
    print("Updating DevPod prerelease package...")

    # Get version from command line or fetch latest prerelease
    version_arg = sys.argv[1] if len(sys.argv) > 1 else None
    version, assets = get_version(version_arg)

    if not version:
        print("No suitable release found")
        sys.exit(1)

    print(f"Target version: {version}")

    # Get checksums for all platforms
    checksums = get_checksums(version, assets)

    # Update the recipe
    update_recipe(version, checksums)

    print("DevPod prerelease package update complete!")


if __name__ == "__main__":
    main()
