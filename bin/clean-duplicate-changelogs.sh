#!/usr/bin/env bash
# Remove duplicate consecutive CHANGELOG version headers from infinite loop
set -euo pipefail

cd "$(dirname "$0")/.."

for plugin_dir in plugins/*; do
  if [ ! -d "$plugin_dir" ]; then
    continue
  fi

  CHANGELOG="$plugin_dir/CHANGELOG.md"
  if [ ! -f "$CHANGELOG" ]; then
    continue
  fi

  plugin_name=$(basename "$plugin_dir")

  # Remove duplicate consecutive lines matching "## X.Y.Z (date)"
  # Keep only the first occurrence of each version header
  awk '
    /^## [0-9]+\.[0-9]+\.[0-9]+ \([0-9]{4}-[0-9]{2}-[0-9]{2}\)/ {
      if (seen[$0]++) next
    }
    { print }
  ' "$CHANGELOG" > "$CHANGELOG.tmp"

  # Check if file changed
  if ! cmp -s "$CHANGELOG" "$CHANGELOG.tmp"; then
    mv "$CHANGELOG.tmp" "$CHANGELOG"
    echo "✓ Cleaned $plugin_name"
  else
    rm "$CHANGELOG.tmp"
    echo "  $plugin_name - no duplicates"
  fi
done

echo ""
echo "All CHANGELOGs cleaned!"
