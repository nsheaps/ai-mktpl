#!/usr/bin/env bash
# Install enabled plugins on session start (web sessions only).
# Locally, Claude Code auto-resolves enabled plugins; web sessions need this explicit step.
set -euo pipefail

echo "[01-install-plugins] Hook started at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "[01-install-plugins] CLAUDE_CODE_REMOTE=${CLAUDE_CODE_REMOTE:-<not set>}"
echo "[01-install-plugins] CLAUDE_PROJECT_DIR=${CLAUDE_PROJECT_DIR:-<not set>}"
echo "[01-install-plugins] PWD=$(pwd)"

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
    echo "[01-install-plugins] Not a web session, exiting."
    exit 0
fi

SETTINGS_FILE="${CLAUDE_PROJECT_DIR}/.claude/settings.json"
echo "[01-install-plugins] Looking for settings at: $SETTINGS_FILE"

if [ ! -f "$SETTINGS_FILE" ]; then
    echo "[01-install-plugins] No .claude/settings.json found, skipping plugin installation."
    exit 0
fi

echo "[01-install-plugins] Settings file found."

# Read enabled plugins (keys where value is true) from settings.json
PLUGINS=()
_tmp=$(jq -r '.enabledPlugins | to_entries[] | select(.value == true) | .key' "$SETTINGS_FILE")
while IFS= read -r plugin; do
    [ -n "$plugin" ] && PLUGINS+=("$plugin")
done <<< "$_tmp"

if [ ${#PLUGINS[@]} -eq 0 ]; then
    echo "[01-install-plugins] No enabled plugins found in settings.json."
    exit 0
fi

echo "[01-install-plugins] Enabled plugins to install: ${PLUGINS[*]}"

# Run marketplace update from the project directory so `claude` picks up
# extraKnownMarketplaces from the project settings.json.
echo "[01-install-plugins] Updating plugin marketplace (cwd: $CLAUDE_PROJECT_DIR)..."
(cd "$CLAUDE_PROJECT_DIR" && claude plugin marketplace update 2>&1) \
    || echo "  [warn] Marketplace update failed, continuing with cached index..."
echo "[01-install-plugins] Marketplace update done."

echo "[01-install-plugins] Installing enabled plugins..."
for plugin in "${PLUGINS[@]}"; do
    echo "[01-install-plugins]   -> Installing $plugin"
    (cd "$CLAUDE_PROJECT_DIR" && claude plugin install "$plugin" --scope project 2>&1) \
        && echo "[01-install-plugins]   OK: $plugin" \
        || echo "[01-install-plugins]   [warn] Failed to install $plugin, continuing..."
done
echo "[01-install-plugins] Plugin installation complete."
