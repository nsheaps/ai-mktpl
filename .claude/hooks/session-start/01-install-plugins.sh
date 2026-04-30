#!/usr/bin/env bash
# Install enabled plugins on session start (web sessions only).
# Locally, Claude Code auto-resolves enabled plugins; web sessions need this explicit step.
set -euo pipefail

# Inlined log helpers (this hook runs BEFORE any plugins are installed, so it
# cannot depend on the shared-lib plugin's helpers). Mirrors shared-lib/lib/log.sh.
LOG_PREFIX="01-install-plugins"
log_info() { echo "${LOG_PREFIX}: $1" >&2; }
log_warn() { echo "${LOG_PREFIX}: [warn] $1" >&2; }
log_error() { echo "${LOG_PREFIX}: [error] $1" >&2; }
log_step() { echo "${LOG_PREFIX}: [$1] $2" >&2; }

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

# --- Run plugin lifecycle hooks for newly installed plugins ---
# On a fresh session, plugins are installed above but their lifecycle hooks
# (Setup{init} and SessionStart) never fire because those events already
# happened before plugins existed. We manually discover and execute those
# hooks here, mirroring what the agent launcher does via `claude --init-only`
# in interactive sessions.
#
# Order matters:
#   1. Setup{trigger:"init"} hooks fire first — these set up persistent
#      data (e.g. shared-lib copies bundled libs into CLAUDE_PLUGIN_DATA).
#   2. SessionStart hooks fire second — by then any state Setup hooks
#      created is on disk for SessionStart hooks to consume.
#
# We also walk the dependency graph: a plugin in INSTALLED_PLUGINS may pull
# in transitive deps (e.g. mise depends on shared-lib) that were installed
# by `claude plugin install` but aren't in `enabledPlugins` themselves.
# Those deps' lifecycle hooks must also fire here, otherwise dependents'
# wait-and-source guards will time out.

PLUGIN_CACHE="${HOME}/.claude/plugins/cache"

# Resolve the plugin cache directory for a given spec ("name@marketplace").
# Prints the resolved directory on stdout. Returns non-zero on failure.
_resolve_plugin_dir() {
    local plugin_spec="$1"
    local plugin_name marketplace cache_base plugin_dir
    plugin_name="${plugin_spec%%@*}"
    marketplace="${plugin_spec##*@}"
    if [ -z "$marketplace" ] || [ "$marketplace" = "$plugin_spec" ]; then
        return 1
    fi
    cache_base="${PLUGIN_CACHE}/${marketplace}/${plugin_name}"
    [ -d "$cache_base" ] || return 1
    plugin_dir="$(ls -1d "${cache_base}/"*/ 2>/dev/null | sort -V | tail -1)"
    [ -n "$plugin_dir" ] || return 1
    printf "%s" "${plugin_dir%/}"
}

# Read transitive dependencies declared in a plugin's plugin.json.
# Prints "name@marketplace" specs on stdout, one per line.
# Per Claude Code plugin-deps docs, deps default to the same marketplace
# as the parent plugin if `.marketplace` is not set on the dep entry.
_discover_dependencies() {
    local plugin_spec="$1"
    local marketplace="${plugin_spec##*@}"
    local plugin_dir plugin_json
    plugin_dir="$(_resolve_plugin_dir "$plugin_spec")" || return 0
    plugin_json="${plugin_dir}/.claude-plugin/plugin.json"
    [ -f "$plugin_json" ] || return 0
    jq -r --arg m "$marketplace" '
        .dependencies // [] | .[] |
        "\(.name)@\(.marketplace // $m)"
    ' "$plugin_json" 2>/dev/null
}

# Build the full set of installed plugins by walking dependencies BFS-style.
# Result is in ALL_PLUGIN_SPECS (in discovery order: roots before transitive deps).
ALL_PLUGIN_SPECS=()
declare -A _seen_plugin
_walk_deps() {
    local queue=("$@")
    while [ ${#queue[@]} -gt 0 ]; do
        local spec="${queue[0]}"
        queue=("${queue[@]:1}")
        if [ -n "${_seen_plugin[$spec]:-}" ]; then
            continue
        fi
        _seen_plugin[$spec]=1
        ALL_PLUGIN_SPECS+=("$spec")
        # Append discovered deps to the queue
        while IFS= read -r dep; do
            [ -z "$dep" ] && continue
            queue+=("$dep")
        done < <(_discover_dependencies "$spec")
    done
}

# Run lifecycle hooks for a single plugin.
#   $1 — plugin spec ("name@marketplace")
#   $2 — event name ("Setup" or "SessionStart")
#   $3 — matcher ("init" for Setup{init}, empty to match all matchers)
run_plugin_hooks() {
    local plugin_spec="$1"
    local event="$2"
    local matcher="${3:-}"
    local plugin_name marketplace plugin_dir hooks_file

    plugin_name="${plugin_spec%%@*}"
    marketplace="${plugin_spec##*@}"

    plugin_dir="$(_resolve_plugin_dir "$plugin_spec")" || {
        log_step "hooks" "Cannot resolve plugin dir for '$plugin_spec', skipping"
        return 0
    }

    hooks_file="${plugin_dir}/hooks/hooks.json"
    if [ ! -f "$hooks_file" ]; then
        return 0
    fi

    # Extract command strings for this event (and matcher, if specified).
    # Use `local commands=$(...)` so `local` swallows jq's exit code under set -e.
    local commands
    if [ -n "$matcher" ]; then
        commands=$(jq -r --arg evt "$event" --arg m "$matcher" '
            .hooks[$evt] // [] | .[] |
            select((.matcher // "") == $m) |
            .hooks // [] | .[] |
            select(.type == "command") |
            .command
        ' "$hooks_file" 2>/dev/null)
    else
        commands=$(jq -r --arg evt "$event" '
            .hooks[$evt] // [] | .[] |
            .hooks // [] | .[] |
            select(.type == "command") |
            .command
        ' "$hooks_file" 2>/dev/null)
    fi

    if [ -z "$commands" ]; then
        return 0
    fi

    # Compute CLAUDE_PLUGIN_DATA per the documented format:
    # `~/.claude/plugins/data/{plugin-id}/` where plugin-id is
    # `{plugin-name}-{marketplace-name}` with non-[a-zA-Z0-9_-] chars replaced
    # by `-`. See https://code.claude.com/docs/en/plugins-reference#persistent-data-directory
    local plugin_id="${plugin_name}-${marketplace}"
    plugin_id="${plugin_id//[^a-zA-Z0-9_-]/-}"
    local plugin_data="${HOME}/.claude/plugins/data/${plugin_id}"
    mkdir -p "$plugin_data"

    local label="$event"
    [ -n "$matcher" ] && label="${event}{${matcher}}"
    log_step "hooks" "Running ${label} hooks for $plugin_name..."
    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        # Replace ${CLAUDE_PLUGIN_ROOT} and ${CLAUDE_PLUGIN_DATA} with actual paths
        local resolved_cmd="${cmd//\$\{CLAUDE_PLUGIN_ROOT\}/$plugin_dir}"
        resolved_cmd="${resolved_cmd//\$\{CLAUDE_PLUGIN_DATA\}/$plugin_data}"
        log_step "hooks" "  -> $resolved_cmd"
        (
            export CLAUDE_PLUGIN_ROOT="$plugin_dir"
            export CLAUDE_PLUGIN_DATA="$plugin_data"
            cd "$CLAUDE_PROJECT_DIR"
            eval "$resolved_cmd"
        ) || log_warn "[hooks] ${label} hook command failed for $plugin_name (exit $?), continuing..."
    done <<< "$commands"
}

if [ ${#INSTALLED_PLUGINS[@]} -gt 0 ]; then
    log_info "Discovering plugin dependency graph..."
    _walk_deps "${INSTALLED_PLUGINS[@]}"
    log_info "Plugins to process (incl. transitive deps): ${ALL_PLUGIN_SPECS[*]}"

    # Phase 1: Setup{trigger:"init"} hooks across all plugins.
    # This is the web-session equivalent of `claude --init-only`'s pre-pass:
    # it lets infrastructure plugins (e.g. shared-lib) prepare persistent data
    # before any SessionStart hook in a dependent plugin tries to consume it.
    log_info "Running Setup{init} hooks..."
    for plugin in "${ALL_PLUGIN_SPECS[@]}"; do
        run_plugin_hooks "$plugin" "Setup" "init"
    done
    log_info "Setup{init} hooks complete."

    # Phase 2: SessionStart hooks across all plugins.
    log_info "Running SessionStart hooks..."
    for plugin in "${ALL_PLUGIN_SPECS[@]}"; do
        run_plugin_hooks "$plugin" "SessionStart" ""
    done
    log_info "SessionStart hooks complete."
else
    log_info "No plugins installed, skipping lifecycle hooks."
fi
