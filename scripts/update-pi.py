#!/usr/bin/env python3
"""
Update script for pi package in the blooop-feedstock.

This script monitors the earendil-works/pi GitHub repository for new releases
and updates the recipe with the latest version and checksums for all platforms.

GITHUB_REPO must match the repo name in the recipe's source URLs: update_recipe()
rewrites those URLs with a pattern built from it, and a mismatch would leave the
old version in the URLs while the sha256s move on — a build failure at best.
Upstream renamed badlogic/pi-mono -> earendil-works/pi; both are kept in step here.
"""

import hashlib
import json
import re
import sys
import urllib.request
from pathlib import Path

GITHUB_REPO = "earendil-works/pi"
GITHUB_API_URL = f"https://api.github.com/repos/{GITHUB_REPO}/releases/latest"
RECIPE_PATH = Path("recipes/pi/recipe.yaml")

PLATFORM_ASSETS = {
    "linux-64": "pi-linux-x64.tar.gz",
    "linux-aarch64": "pi-linux-arm64.tar.gz",
    "osx-64": "pi-darwin-x64.tar.gz",
    "osx-arm64": "pi-darwin-arm64.tar.gz",
    "win-64": "pi-windows-x64.zip",
}


def get_latest_release() -> tuple[str, dict[str, str]]:
    """Fetch latest release version and asset URL map from GitHub API."""
    try:
        with urllib.request.urlopen(GITHUB_API_URL) as response:
            data = json.loads(response.read().decode())
        version = data["tag_name"].lstrip("v")
        assets = {asset["name"]: asset["browser_download_url"] for asset in data.get("assets", [])}
        return version, assets
    except Exception as e:
        print(f"❌ Failed to fetch latest release: {e}")
        sys.exit(1)


def get_version(version_arg: str | None = None) -> tuple[str, dict[str, str] | None]:
    """Get version from argument or latest release."""
    if version_arg:
        return version_arg, None
    return get_latest_release()


def download_and_hash(url: str) -> str:
    """Download and return SHA256 hash."""
    print(f"  📥 Downloading {url.split('/')[-1]}...")
    try:
        with urllib.request.urlopen(url) as response:
            data = response.read()
        sha256 = hashlib.sha256(data).hexdigest()
        print(f"  ✅ SHA256: {sha256}")
        return sha256
    except Exception as e:
        print(f"  ❌ Failed to download {url}: {e}")
        return ""


def get_checksums(version: str, assets: dict[str, str] | None = None) -> dict[str, str]:
    """Resolve all platform checksums."""
    if assets is None:
        base_url = f"https://github.com/{GITHUB_REPO}/releases/download/v{version}"
        assets = {name: f"{base_url}/{name}" for name in PLATFORM_ASSETS.values()}

    checksums: dict[str, str] = {}
    print("📦 Fetching checksums for all platforms...")
    for platform, asset_name in PLATFORM_ASSETS.items():
        url = assets.get(asset_name)
        if not url:
            print(f"  ⚠️ Missing asset for {platform}: {asset_name}")
            checksums[platform] = ""
            continue
        checksums[platform] = download_and_hash(url)
    return checksums


def update_recipe(version: str, checksums: dict[str, str]) -> None:
    """Update recipes/pi/recipe.yaml with new version + sha256s."""
    if not RECIPE_PATH.exists():
        print(f"❌ Recipe file not found: {RECIPE_PATH}")
        sys.exit(1)

    recipe = RECIPE_PATH.read_text()

    current_match = re.search(r'version:\s*"([^"]+)"', recipe)
    current_version = current_match.group(1) if current_match else None

    # Update package version
    recipe = re.sub(
        r'(package:\s*\n\s*name:\s*pi\s*\n\s*version:\s*)"[^"]+"',
        rf'\1"{version}"',
        recipe,
        count=1,
    )

    # Update URLs and hashes by target_directory
    for platform, asset_name in PLATFORM_ASSETS.items():
        checksum = checksums.get(platform, "")
        if not checksum:
            continue

        url_pattern = rf'(url:\s*https://github.com/{re.escape(GITHUB_REPO)}/releases/download/v)[^/]+(/{re.escape(asset_name)})'
        recipe = re.sub(url_pattern, rf'\g<1>{version}\g<2>', recipe)

        sha_pattern = rf'(sha256:\s*)[0-9a-f]{{64}}(\s*\n\s*target_directory:\s*{re.escape(platform)})'
        recipe = re.sub(sha_pattern, rf'\g<1>{checksum}\g<2>', recipe)
        print(f"  ✅ Updated {platform}")

    # Reset build number only if upstream version changed
    if current_version and current_version != version:
        recipe = re.sub(r'(build:\s*\n\s*number:\s*)\d+', r'\g<1>0', recipe, count=1)
        print(f"✅ Updated version {current_version} -> {version}, reset build number to 0")
    else:
        print(f"✅ Version unchanged ({version}); keeping build number")

    RECIPE_PATH.write_text(recipe)


def main() -> None:
    print("🔄 Updating pi recipe...")
    version_arg = sys.argv[1] if len(sys.argv) > 1 else None
    version, assets = get_version(version_arg)
    print(f"📦 Target version: {version}")

    checksums = get_checksums(version, assets)
    if any(not v for v in checksums.values()):
        print("❌ One or more platform checksums could not be resolved")
        sys.exit(1)

    update_recipe(version, checksums)
    print("🎉 pi recipe update complete")


if __name__ == "__main__":
    main()
