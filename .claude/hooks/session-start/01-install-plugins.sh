#!/usr/bin/env bash
# Install enabled plugins on session start (web sessions only).
# Locally, Claude Code auto-resolves enabled plugins; web sessions need this explicit step.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
    exit 0
fi

SETTINGS_FILE="${CLAUDE_PROJECT_DIR}/.claude/settings.json"

if [ ! -f "$SETTINGS_FILE" ]; then
    echo "No .claude/settings.json found, skipping plugin installation."
    exit 0
fi

# Read enabled plugins (keys where value is true) from settings.json
PLUGINS=()
_tmp=$(jq -r '.enabledPlugins | to_entries[] | select(.value == true) | .key' "$SETTINGS_FILE")
while IFS= read -r plugin; do
    [ -n "$plugin" ] && PLUGINS+=("$plugin")
done <<< "$_tmp"

if [ ${#PLUGINS[@]} -eq 0 ]; then
    echo "No enabled plugins found in settings.json."
    exit 0
fi

echo "Installing enabled plugins..."
for plugin in "${PLUGINS[@]}"; do
    echo "  -> $plugin"
    claude plugin install "$plugin" --scope project 2>&1 || echo "  [warn] Failed to install $plugin, continuing..."
done
echo "Plugin installation complete."
