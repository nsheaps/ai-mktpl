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
INSTALLED_PLUGINS=()
for plugin in "${PLUGINS[@]}"; do
    echo "[01-install-plugins]   -> Installing $plugin"
    if (cd "$CLAUDE_PROJECT_DIR" && claude plugin install "$plugin" --scope project 2>&1); then
        echo "[01-install-plugins]   OK: $plugin"
        INSTALLED_PLUGINS+=("$plugin")
    else
        echo "[01-install-plugins]   [warn] Failed to install $plugin, continuing..."
    fi
done
echo "[01-install-plugins] Plugin installation complete."

# --- Run SessionStart hooks for newly installed plugins ---
# On a fresh session, plugins are installed above but their SessionStart hooks
# never fire because the SessionStart event already happened before plugins existed.
# We manually discover and execute those hooks here.

PLUGIN_CACHE="${HOME}/.claude/plugins/cache"

run_plugin_session_hooks() {
    local plugin_spec="$1"  # e.g. "mise@ai-mktpl"
    local plugin_name marketplace plugin_dir hooks_file

    # Parse plugin@marketplace
    plugin_name="${plugin_spec%%@*}"
    marketplace="${plugin_spec##*@}"

    if [ -z "$marketplace" ] || [ "$marketplace" = "$plugin_spec" ]; then
        echo "[01-install-plugins]   [hooks] Cannot parse marketplace from '$plugin_spec', skipping"
        return 0
    fi

    # Find the plugin cache directory (pick latest version by modification time)
    local cache_base="${PLUGIN_CACHE}/${marketplace}/${plugin_name}"
    if [ ! -d "$cache_base" ]; then
        echo "[01-install-plugins]   [hooks] No cache dir for $plugin_spec, skipping"
        return 0
    fi

    # Get the latest version directory by semver sorting
    plugin_dir="$(ls -1d "${cache_base}/"*/ 2>/dev/null | sort -V | tail -1)"
    if [ -z "$plugin_dir" ]; then
        echo "[01-install-plugins]   [hooks] No version dir in $cache_base, skipping"
        return 0
    fi
    # Remove trailing slash
    plugin_dir="${plugin_dir%/}"

    hooks_file="${plugin_dir}/hooks/hooks.json"
    if [ ! -f "$hooks_file" ]; then
        echo "[01-install-plugins]   [hooks] No hooks.json for $plugin_name, skipping"
        return 0
    fi

    # Extract SessionStart hook commands from hooks.json
    # Use `local commands=$(...)` so `local` swallows jq's exit code under set -e
    local commands=$(jq -r '
        .hooks.SessionStart // [] | .[] |
        .hooks // [] | .[] |
        select(.type == "command") |
        .command
    ' "$hooks_file" 2>/dev/null)

    if [ -z "$commands" ]; then
        echo "[01-install-plugins]   [hooks] No SessionStart hooks for $plugin_name"
        return 0
    fi

    echo "[01-install-plugins]   [hooks] Running SessionStart hooks for $plugin_name..."
    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        # Replace ${CLAUDE_PLUGIN_ROOT} with the actual plugin directory
        local resolved_cmd="${cmd//\$\{CLAUDE_PLUGIN_ROOT\}/$plugin_dir}"
        echo "[01-install-plugins]   [hooks]   -> $resolved_cmd"
        (
            export CLAUDE_PLUGIN_ROOT="$plugin_dir"
            cd "$CLAUDE_PROJECT_DIR"
            # Redirect stdout to stderr — plugin hooks output JSON via hook_respond
            # which would corrupt the parent hook's output if left on stdout
            eval "$resolved_cmd" >&2
        ) || echo "[01-install-plugins]   [hooks]   [warn] Hook command failed for $plugin_name (exit $?), continuing..."
    done <<< "$commands"
}

if [ ${#INSTALLED_PLUGINS[@]} -gt 0 ]; then
    echo "[01-install-plugins] Running SessionStart hooks for installed plugins..."
    for plugin in "${INSTALLED_PLUGINS[@]}"; do
        run_plugin_session_hooks "$plugin"
    done
    echo "[01-install-plugins] Plugin SessionStart hooks complete."
else
    echo "[01-install-plugins] No plugins installed, skipping SessionStart hooks."
fi
