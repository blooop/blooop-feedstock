#!/usr/bin/env python3
"""
Update script for the isd package in the blooop-feedstock.

isd is published on PyPI as "isd-tui" (the executable is still "isd"). This
script monitors PyPI for new releases and updates the recipe with the latest
version, sdist URL, and SHA256 checksum.
"""

import sys
import re
import json
from pathlib import Path
import urllib.request

PYPI_PROJECT = "isd-tui"
PYPI_URL = f"https://pypi.org/pypi/{PYPI_PROJECT}/json"
RECIPE_PATH = Path("recipes/isd/recipe.yaml")


def fetch_release(version: str | None) -> tuple[str, str, str]:
    """Return (version, sdist_url, sha256) for the given or latest version."""
    url = PYPI_URL if version is None else f"https://pypi.org/pypi/{PYPI_PROJECT}/{version}/json"
    try:
        with urllib.request.urlopen(url) as response:
            data = json.loads(response.read().decode())
    except Exception as e:
        print(f"❌ Failed to fetch release info: {e}")
        sys.exit(1)

    version = data["info"]["version"]

    # The releases dict carries the per-version files; the top-level "urls" is
    # only the latest, so use releases[version] to support a pinned version.
    files = data.get("releases", {}).get(version) or data.get("urls", [])
    for f in files:
        if f.get("packagetype") == "sdist":
            return version, f["url"], f["digests"]["sha256"]

    print(f"❌ No sdist found for {PYPI_PROJECT} {version}")
    sys.exit(1)


def update_recipe(version: str, sdist_url: str, sha256: str) -> None:
    if not RECIPE_PATH.exists():
        print(f"❌ Recipe file not found: {RECIPE_PATH}")
        sys.exit(1)

    recipe = RECIPE_PATH.read_text()

    current_match = re.search(r'version: "([^"]+)"', recipe)
    current_version = current_match.group(1) if current_match else None

    # Update version in the package section
    recipe = re.sub(r'(package:.*?version:\s*)"[^"]+"', f'\\1"{version}"', recipe, count=1, flags=re.DOTALL)

    # Update the sdist URL and SHA256
    recipe = re.sub(r'(-\s*url:\s*)https://files\.pythonhosted\.org/\S+', rf'\g<1>{sdist_url}', recipe)
    recipe = re.sub(r'(sha256:\s*)[\da-f]{64}', rf'\g<1>{sha256}', recipe)

    if current_version != version:
        recipe = re.sub(r'number: \d+', 'number: 0', recipe)
        print(f"✅ Updated isd version from {current_version} to {version}")
    else:
        print(f"✅ Version {version} is already current")

    RECIPE_PATH.write_text(recipe)


def main() -> None:
    print("🔄 Updating isd package...")
    requested = sys.argv[1] if len(sys.argv) > 1 else None
    version, sdist_url, sha256 = fetch_release(requested)
    print(f"📦 Target version: {version}")
    print(f"  ✅ SHA256: {sha256}")
    update_recipe(version, sdist_url, sha256)
    print("🎉 isd package update complete!")


if __name__ == "__main__":
    main()
