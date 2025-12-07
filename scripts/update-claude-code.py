#!/usr/bin/env python3
"""
Update script for claude-code package in the blooop-feedstock.

This script fetches the latest version of Claude Code and updates
the recipe.yaml file with new version and checksums.
"""

import json
import sys
import re
from pathlib import Path
import urllib.request
from typing import Dict, Optional

BASE_URL = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"
RECIPE_PATH = Path("recipes/claude-code/recipe.yaml")

# Mapping from manifest platform names to conda platform selectors
PLATFORM_MAPPING = {
    "linux-x64": "linux and x86_64",
    "linux-arm64": "linux and aarch64", 
    "darwin-x64": "osx and x86_64",
    "darwin-arm64": "osx and arm64",
    "win32-x64": "win"
}

def get_version(version_arg: Optional[str] = None) -> str:
    """Get Claude Code version - either from argument or fetch latest stable."""
    if version_arg:
        return version_arg
    
    try:
        with urllib.request.urlopen(f"{BASE_URL}/stable") as response:
            return response.read().decode().strip()
    except Exception as e:
        print(f"❌ Failed to fetch stable version: {e}")
        sys.exit(1)

def get_manifest(version: str) -> Dict:
    """Fetch the manifest for a specific version."""
    try:
        with urllib.request.urlopen(f"{BASE_URL}/{version}/manifest.json") as response:
            return json.loads(response.read())
    except Exception as e:
        print(f"❌ Failed to fetch manifest for version {version}: {e}")
        sys.exit(1)

def update_recipe(version: str, manifest: Dict) -> None:
    """Update the recipe.yaml file with new version and checksums."""
    if not RECIPE_PATH.exists():
        print(f"❌ Recipe file not found: {RECIPE_PATH}")
        sys.exit(1)

    recipe = RECIPE_PATH.read_text()
    
    # Update version
    recipe = re.sub(r'version: "[^"]+"', f'version: "{version}"', recipe, count=1)
    
    # Update URLs to use actual version numbers instead of templates
    platforms_data = manifest.get("platforms", {})
    for platform, platform_data in platforms_data.items():
        if platform in PLATFORM_MAPPING:
            checksum = platform_data.get("checksum")
            if checksum:
                # Update both the URL and the checksum for this platform
                platform_selector = PLATFORM_MAPPING[platform]
                
                # Update URL with actual version
                if platform == "win32-x64":
                    url_pattern = rf"(https://storage\.googleapis\.com/claude-code-dist-[^/]+/claude-code-releases/)[^/]+(/win32-x64/claude-code\.zip)"
                    recipe = re.sub(url_pattern, f"\\g<1>{version}\\g<2>", recipe)
                else:
                    url_pattern = rf"(https://storage\.googleapis\.com/claude-code-dist-[^/]+/claude-code-releases/)[^/]+(/[^/]+/claude-code\.tar\.gz)"
                    recipe = re.sub(url_pattern, f"\\g<1>{version}\\g<2>", recipe)
                
                # Update checksum
                pattern = rf"(# \[{re.escape(platform_selector)}\]\s*\n\s*sha256:\s*)[a-f0-9]+"
                replacement = f"\\g<1>{checksum}"
                recipe = re.sub(pattern, replacement, recipe, flags=re.MULTILINE)
                print(f"✅ Updated {platform} URL and checksum")
    
    # Reset build number to 0 for new version
    recipe = re.sub(r'number: \d+', 'number: 0', recipe)
    
    RECIPE_PATH.write_text(recipe)
    print(f"✅ Updated recipe to version {version}")

def main():
    """Main function to update Claude Code recipe."""
    print("🔄 Updating Claude Code recipe...")
    
    # Get version from command line or fetch latest
    version = get_version(sys.argv[1] if len(sys.argv) > 1 else None)
    print(f"📦 Target version: {version}")
    
    # Fetch manifest for this version
    manifest = get_manifest(version)
    
    # Update the recipe
    update_recipe(version, manifest)
    
    print("🎉 Claude Code recipe update complete!")

if __name__ == "__main__":
    main()
