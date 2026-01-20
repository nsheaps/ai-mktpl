#!/usr/bin/env bash
# Generate .release-it.js files for all plugins
# Using simple patch bumps - the conventional-changelog plugin doesn't work well
# with path filtering in a monorepo without tags.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

for plugin_dir in "$ROOT_DIR"/plugins/*; do
  if [ -d "$plugin_dir" ]; then
    plugin_name=$(basename "$plugin_dir")
    config_file="$plugin_dir/.release-it.js"

    cat > "$config_file" << 'EOF'
module.exports = {
  extends: "../../.release-it.base.json",
  plugins: {
    "@release-it/bumper": {
      in: ".claude-plugin/plugin.json",
      out: ".claude-plugin/plugin.json",
    },
  },
};
EOF

    echo "Created $config_file"
  fi
done

echo "Done generating .release-it.js files"
