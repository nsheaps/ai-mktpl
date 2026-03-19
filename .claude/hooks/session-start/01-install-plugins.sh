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

# Seed known_marketplaces.json from extraKnownMarketplaces in settings.json.
# On fresh sessions, the Claude runtime hasn't yet populated the plugin registry
# from settings.json, so `claude plugin marketplace update` reports
# "No marketplaces configured". Explicitly registering them first fixes this.
KNOWN_MARKETPLACES="${HOME}/.claude/plugins/known_marketplaces.json"
echo "[01-install-plugins] Seeding marketplaces from extraKnownMarketplaces..."
while IFS="=" read -r name repo; do
    [ -z "$name" ] && continue
    # Check if already registered (has an installLocation)
    already_registered=$(jq -r --arg n "$name" '.[$n].installLocation // empty' "$KNOWN_MARKETPLACES" 2>/dev/null || true)
    if [ -z "$already_registered" ]; then
        echo "[01-install-plugins]   -> Registering marketplace: $name ($repo)"
        (cd "$CLAUDE_PROJECT_DIR" && claude plugin marketplace add "$repo" --scope user 2>&1) \
            || echo "[01-install-plugins]   [warn] Failed to register $name, continuing..."
    else
        echo "[01-install-plugins]   -> Already registered: $name"
    fi
done < <(jq -r '.extraKnownMarketplaces | to_entries[] | select(.value.source.source == "github") | .key + "=" + .value.source.repo' "$SETTINGS_FILE" 2>/dev/null || true)

# Run marketplace update to fetch latest plugin indexes.
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
