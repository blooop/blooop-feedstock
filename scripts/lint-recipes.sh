#!/usr/bin/env bash
# Parse every recipe so a YAML-level mistake fails here rather than three
# minutes into a release build.
#
# This lives in a script rather than inline in pixi.toml because pixi runs
# tasks through its own shell, which has no `for` loop -- the inline version
# died with "Unsupported reserved word" before it ever parsed a recipe.
set -euo pipefail

cd "$(dirname "$0")/.."

failed=0
checked=0
for recipe in recipes/*/recipe.yaml; do
    [ -e "$recipe" ] || continue
    checked=$((checked + 1))
    if python -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" "$recipe"; then
        echo "  ok   $recipe"
    else
        echo "  FAIL $recipe" >&2
        failed=$((failed + 1))
    fi
done

if [ "$checked" -eq 0 ]; then
    echo "No recipes found -- refusing to report success." >&2
    exit 1
fi

echo "Checked $checked recipe(s), $failed failure(s)."
[ "$failed" -eq 0 ]
