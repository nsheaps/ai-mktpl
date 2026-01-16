#!/usr/bin/env bash
# Update all .versionrc.js files to include plugin name and run prettier

set -euo pipefail

cd "$(dirname "$0")/.."

for plugin_dir in plugins/*; do
    if [ ! -d "$plugin_dir" ]; then
        continue
    fi

    plugin_name=$(basename "$plugin_dir")
    versionrc="$plugin_dir/.versionrc.js"

    if [ ! -f "$versionrc" ]; then
        echo "Skipping $plugin_name (no .versionrc.js)"
        continue
    fi

    cat > "$versionrc" <<EOF
module.exports = {
  releaseCommitMessageFormat: "chore($plugin_name): release {{currentTag}}",
  scripts: {
    postbump: "prettier --write .claude-plugin/plugin.json"
  },
  skip: {
    bump: false,
    changelog: false,
    commit: false,
    tag: true,
  },
  tagPrefix: "$plugin_name@",
  packageFiles: [
    {
      filename: ".claude-plugin/plugin.json",
      type: "json",
    },
  ],
  bumpFiles: [
    {
      filename: ".claude-plugin/plugin.json",
      type: "json",
    },
  ],
};
EOF

    echo "✓ Updated $plugin_name"
done

echo ""
echo "All .versionrc.js files updated!"
echo "Changes:"
echo "  - Commit message now includes plugin name: chore(plugin-name): release X.Y.Z"
echo "  - Removed [skip ci] tag"
echo "  - Added postbump script to run prettier on plugin.json"
