#!/usr/bin/env bash
# Install enabled plugins on session start (web sessions only).
# Locally, Claude Code auto-resolves enabled plugins; web sessions need this explicit step.
set -euo pipefail

# Source shared logging library
LOG_PREFIX="01-install-plugins"
# shellcheck source=../../../shared/lib/log.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../shared/lib/log.sh"

log_info "Hook started at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
log_info "CLAUDE_CODE_REMOTE=${CLAUDE_CODE_REMOTE:-<not set>}"
log_info "CLAUDE_PROJECT_DIR=${CLAUDE_PROJECT_DIR:-<not set>}"
log_info "PWD=$(pwd)"

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
    log_info "Not a web session, exiting."
    exit 0
fi

SETTINGS_FILE="${CLAUDE_PROJECT_DIR}/.claude/settings.json"
log_info "Looking for settings at: $SETTINGS_FILE"

if [ ! -f "$SETTINGS_FILE" ]; then
    log_info "No .claude/settings.json found, skipping plugin installation."
    exit 0
fi

log_info "Settings file found."

# Read enabled plugins (keys where value is true) from settings.json
PLUGINS=()
_tmp=$(jq -r '.enabledPlugins | to_entries[] | select(.value == true) | .key' "$SETTINGS_FILE")
while IFS= read -r plugin; do
    [ -n "$plugin" ] && PLUGINS+=("$plugin")
done <<< "$_tmp"

if [ ${#PLUGINS[@]} -eq 0 ]; then
    log_info "No enabled plugins found in settings.json."
    exit 0
fi

log_info "Enabled plugins to install: ${PLUGINS[*]}"

# Seed known_marketplaces.json from extraKnownMarketplaces in settings.json.
# On fresh sessions, the Claude runtime hasn't yet populated the plugin registry
# from settings.json, so `claude plugin marketplace update` reports
# "No marketplaces configured". Explicitly registering them first fixes this.
KNOWN_MARKETPLACES="${HOME}/.claude/plugins/known_marketplaces.json"
log_info "Seeding marketplaces from extraKnownMarketplaces..."
while IFS="=" read -r name repo; do
    [ -z "$name" ] && continue
    # Check if already registered (has an installLocation)
    already_registered=$(jq -r --arg n "$name" '.[$n].installLocation // empty' "$KNOWN_MARKETPLACES" 2>/dev/null || true)
    if [ -z "$already_registered" ]; then
        log_info "  -> Registering marketplace: $name ($repo)"
        (cd "$CLAUDE_PROJECT_DIR" && claude plugin marketplace add "$repo" --scope user 2>&1) \
            || log_warn "Failed to register $name, continuing..."
    else
        log_info "  -> Already registered: $name"
    fi
done < <(jq -r '.extraKnownMarketplaces | to_entries[] | select(.value.source.source == "github") | .key + "=" + .value.source.repo' "$SETTINGS_FILE" 2>/dev/null || true)

# Run marketplace update to fetch latest plugin indexes.
log_info "Updating plugin marketplace (cwd: $CLAUDE_PROJECT_DIR)..."
(cd "$CLAUDE_PROJECT_DIR" && claude plugin marketplace update 2>&1) \
    || log_warn "Marketplace update failed, continuing with cached index..."
log_info "Marketplace update done."

log_info "Installing enabled plugins..."
INSTALLED_PLUGINS=()
for plugin in "${PLUGINS[@]}"; do
    log_info "  -> Installing $plugin"
    if (cd "$CLAUDE_PROJECT_DIR" && claude plugin install "$plugin" --scope project 2>&1); then
        log_info "  OK: $plugin"
        INSTALLED_PLUGINS+=("$plugin")
    else
        log_warn "Failed to install $plugin, continuing..."
    fi
done
log_info "Plugin installation complete."

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
        log_step "hooks" "Cannot parse marketplace from '$plugin_spec', skipping"
        return 0
    fi

    # Find the plugin cache directory (pick latest version by modification time)
    local cache_base="${PLUGIN_CACHE}/${marketplace}/${plugin_name}"
    if [ ! -d "$cache_base" ]; then
        log_step "hooks" "No cache dir for $plugin_spec, skipping"
        return 0
    fi

    # Get the latest version directory by semver sorting
    plugin_dir="$(ls -1d "${cache_base}/"*/ 2>/dev/null | sort -V | tail -1)"
    if [ -z "$plugin_dir" ]; then
        log_step "hooks" "No version dir in $cache_base, skipping"
        return 0
    fi
    # Remove trailing slash
    plugin_dir="${plugin_dir%/}"

    hooks_file="${plugin_dir}/hooks/hooks.json"
    if [ ! -f "$hooks_file" ]; then
        log_step "hooks" "No hooks.json for $plugin_name, skipping"
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
        log_step "hooks" "No SessionStart hooks for $plugin_name"
        return 0
    fi

    log_step "hooks" "Running SessionStart hooks for $plugin_name..."
    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        # Replace ${CLAUDE_PLUGIN_ROOT} with the actual plugin directory
        local resolved_cmd="${cmd//\$\{CLAUDE_PLUGIN_ROOT\}/$plugin_dir}"
        log_step "hooks" "  -> $resolved_cmd"
        (
            export CLAUDE_PLUGIN_ROOT="$plugin_dir"
            cd "$CLAUDE_PROJECT_DIR"
            eval "$resolved_cmd"
        ) || log_warn "[hooks] Hook command failed for $plugin_name (exit $?), continuing..."
    done <<< "$commands"
}

if [ ${#INSTALLED_PLUGINS[@]} -gt 0 ]; then
    log_info "Running SessionStart hooks for installed plugins..."
    for plugin in "${INSTALLED_PLUGINS[@]}"; do
        run_plugin_session_hooks "$plugin"
    done
    log_info "Plugin SessionStart hooks complete."
else
    log_info "No plugins installed, skipping SessionStart hooks."
fi
