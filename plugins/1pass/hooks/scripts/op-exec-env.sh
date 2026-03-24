#!/usr/bin/env bash
# op-exec-env.sh — SessionStart hook for injecting 1Password items as environment
#
# Uses op-exec to expose entire 1Password items as environment variables.
# Supports multiple items and multiple output targets (CLAUDE_ENV_FILE,
# settings.local.json). Field values containing op:// references are
# resolved recursively when recursiveResolve is enabled.
set -euo pipefail

PLUGIN_NAME="1pass"
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/hook-logging.sh"

# --- Guards ---

plugin_is_enabled || { hook_log "plugin disabled, skipping op-exec env"; hook_respond; exit 0; }

# --- Read config ---

# Read opExec.items array
op_exec_items="$(plugin_get_config_array "opExec.items")"
if [ -z "$op_exec_items" ]; then
  hook_log "no opExec.items configured, skipping"
  hook_respond
  exit 0
fi

# Read opExec.targets array (default: sessionStartBashEnv, userSettings)
op_exec_targets="$(plugin_get_config_array "opExec.targets")"
if [ -z "$op_exec_targets" ]; then
  op_exec_targets=$'sessionStartBashEnv\nuserSettings'
fi

# Read recursiveResolve (default: true)
recursive_resolve="$(plugin_get_config "opExec.recursiveResolve" "true")"

# --- Dependency checks ---

if ! command -v op-exec &>/dev/null; then
  hook_fail "op-exec" "op-exec not found on PATH" \
    "Install op-exec via mise, Homebrew, or set installOpExec: true in 1pass plugin settings"
  hook_respond
  exit 0
fi

if ! command -v op &>/dev/null; then
  hook_fail "op" "1Password CLI (op) not found on PATH" \
    "Install op via mise or set autoInstall: true in 1pass plugin settings"
  hook_respond
  exit 0
fi

if ! op account list &>/dev/null 2>&1; then
  hook_fail "op auth" "Not signed in to 1Password" \
    "Set OP_SERVICE_ACCOUNT_TOKEN or run 'op signin'"
  hook_respond
  exit 0
fi

# --- Target helpers ---

# Determine which targets are enabled
target_bash_env="false"
target_user_settings="false"

while IFS= read -r target; do
  case "$target" in
    sessionStartBashEnv) target_bash_env="true" ;;
    userSettings)        target_user_settings="true" ;;
    *)
      hook_log "unknown target: $target (expected sessionStartBashEnv or userSettings)"
      ;;
  esac
done <<< "$op_exec_targets"

# Prepare settings.local.json writer if needed
if [ "$target_user_settings" = "true" ]; then
  SETTINGS_FILE="${HOME}/.claude/settings.local.json"
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  if [ ! -f "$SETTINGS_FILE" ]; then
    echo '{}' > "$SETTINGS_FILE"
  fi
fi

# --- Process each item ---

write_to_targets() {
  local env_name="$1"
  local env_value="$2"

  if [ "$target_bash_env" = "true" ] && [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    printf 'export %s=%q\n' "$env_name" "$env_value" >> "$CLAUDE_ENV_FILE"
  fi

  if [ "$target_user_settings" = "true" ]; then
    # Write directly with jq since safe_write_settings doesn't support --arg
    local result
    if result=$(jq --arg key "$env_name" --arg val "$env_value" \
      '.env[$key] = $val' "$SETTINGS_FILE" 2>/dev/null) && [ -n "$result" ]; then
      echo "$result" > "$SETTINGS_FILE"
    fi
  fi
}

process_item() {
  local item_ref="$1"
  hook_log_step "op-exec" "Resolving item: $item_ref"

  # Validate reference format
  if ! [[ "$item_ref" =~ ^op://[^/]+/[^/]+ ]]; then
    hook_fail "op-exec" "Invalid reference format: $item_ref (expected op://vault/item)" \
      "Check opExec.items in plugin settings"
    return 0
  fi

  # Build op-exec flags
  local op_exec_args=()
  if [ "$recursive_resolve" != "true" ]; then
    # op-exec resolves recursively by default; no flag needed to enable it
    # If we wanted to disable it, we'd need to skip — but op-exec always resolves.
    # For now, recursive resolution is always on (it's a feature of op-exec itself).
    true
  fi

  # Run op-exec to get export statements
  local exports
  if ! exports="$(op-exec "$item_ref" 2>/dev/null)"; then
    hook_fail "op-exec" "Failed to resolve item: $item_ref" \
      "Verify the item exists and op has access to the vault"
    return 0
  fi

  if [ -z "$exports" ]; then
    hook_log "no fields found in $item_ref"
    return 0
  fi

  # Parse export statements and write to targets
  local count=0
  while IFS= read -r line; do
    # op-exec outputs: export VAR_NAME=value
    # Strip "export " prefix, then split on first "="
    local assignment="${line#export }"
    local env_name="${assignment%%=*}"
    local env_value="${assignment#*=}"

    # Remove shell quoting from value (op-exec uses printf %q)
    # Use eval to safely unquote
    env_value="$(eval echo "$env_value" 2>/dev/null || echo "$env_value")"

    if [ -n "$env_name" ]; then
      write_to_targets "$env_name" "$env_value"
      count=$((count + 1))
    fi
  done <<< "$exports"

  hook_log "exported $count env vars from $item_ref"
}

# --- Main ---

do_inject() {
  hook_log_step "init" "Injecting 1Password items as environment"

  local targets_desc=""
  [ "$target_bash_env" = "true" ] && targets_desc="sessionStartBashEnv"
  if [ "$target_user_settings" = "true" ]; then
    [ -n "$targets_desc" ] && targets_desc="$targets_desc, "
    targets_desc="${targets_desc}userSettings"
  fi
  hook_log "targets: $targets_desc"
  hook_log "recursiveResolve: $recursive_resolve"

  while IFS= read -r item_ref; do
    [ -z "$item_ref" ] && continue
    process_item "$item_ref"
  done <<< "$op_exec_items"
}

# --- Execute ---

hook_run do_inject
hook_log_cleanup
hook_respond
