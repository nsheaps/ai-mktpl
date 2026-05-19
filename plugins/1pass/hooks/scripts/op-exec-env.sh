#!/usr/bin/env bash
# op-exec-env.sh — SessionStart hook for injecting 1Password items as environment
#
# Uses op-exec to expose entire 1Password items as environment variables.
# Supports multiple items and multiple output targets (CLAUDE_ENV_FILE,
# settings.local.json). Field values containing op:// references are
# resolved recursively by op-exec (always on).
set -euo pipefail

PLUGIN_NAME="1pass"


# --- Source shared libs from shared-lib plugin's persistent data dir ---
#
# shared-lib (declared in plugin.json `dependencies`) copies its lib/*.sh
# files into ${CLAUDE_PLUGIN_DATA}/lib on SessionStart. We resolve its data
# dir by stripping our own data-dir name and appending shared-lib's id.
# Plugin data dir IDs are deterministic: `{plugin-name}-{marketplace-name}`.
# See https://code.claude.com/docs/en/plugins-reference#persistent-data-directory
#
# When CLAUDE_PLUGIN_DATA is unset (e.g. when this script is invoked
# outside a Claude Code hook), fall back to the known path.
if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  SHARED_LIB_DIR="${CLAUDE_PLUGIN_DATA%/*}/shared-lib-ai-mktpl/lib"
else
  SHARED_LIB_DIR="${HOME}/.claude/plugins/data/shared-lib-ai-mktpl/lib"
fi

# Wait up to ~10s for a shared-lib file to appear (handles parallel
# SessionStart hooks where shared-lib's copy may not have completed yet).
_wait_for_shared_lib() {
  local lib="$1"
  local i=0
  while [ ! -f "$SHARED_LIB_DIR/$lib" ]; do
    i=$((i + 1))
    if [ "$i" -ge 20 ]; then
      echo "[1pass] timed out waiting for $SHARED_LIB_DIR/$lib (shared-lib SessionStart copy)" >&2
      exit 1
    fi
    sleep 0.5
  done
}

_wait_for_shared_lib "plugin-config-read.sh"
_wait_for_shared_lib "hook-logging.sh"
_wait_for_shared_lib "env-file.sh"

# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/plugin-config-read.sh"
# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/hook-logging.sh"
# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/env-file.sh"
# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/env-local-target.sh"
# shellcheck source=/dev/null
source "${CLAUDE_PLUGIN_ROOT}/lib/resolve-op-env.sh"

# Script-level tmpdir for secret-bearing tempfiles. EXIT trap ensures cleanup
# on any exit path (normal, error, signal). All tempfiles in process_item()
# are created here so no per-function trap scoping is needed.
_OP_EXEC_TMPDIR="$(mktemp -d)"
trap 'rm -rf "$_OP_EXEC_TMPDIR"' EXIT

# Path for the secrets manifest used by the PostToolUse redaction hook.
# The manifest records each resolved env var NAME (not value) so that
# redact-secrets.sh can look up current values at tool-output scan time.
# CLAUDE_PLUGIN_DATA is set when this script runs as a plugin hook; the
# fallback mirrors the deterministic plugin data path used by Claude Code:
#   ${HOME}/.claude/plugins/data/{plugin-name}-{marketplace-name}
_OP_EXEC_MANIFEST=""
if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  _OP_EXEC_MANIFEST="${CLAUDE_PLUGIN_DATA}/secrets-manifest.txt"
fi

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

# Auth check removed — op-exec already validates auth and provides clear errors.
# Duplicating the check here violates DRY and was using the wrong command
# (op account list) which doesn't work with service account tokens.

# --- Target helpers ---

# Determine which targets are enabled
target_bash_env="false"
target_user_settings="false"
target_env_local="false"

while IFS= read -r target; do
  case "$target" in
    sessionStartBashEnv) target_bash_env="true" ;;
    userSettings)        target_user_settings="true" ;;
    envLocal)            target_env_local="true" ;;
    *)
      hook_log "unknown target: $target (expected sessionStartBashEnv, userSettings, or envLocal)"
      ;;
  esac
done <<< "$op_exec_targets"

# Resolve envLocal target path once (used in the per-var writer below).
ENV_LOCAL_PATH=""
ENV_LOCAL_SOURCE_CHAIN_WRITTEN="false"
if [ "$target_env_local" = "true" ]; then
  ENV_LOCAL_PATH="$(_resolve_env_local_path)"
  if [ -z "$ENV_LOCAL_PATH" ]; then
    hook_log "envLocal target requested but no path could be resolved (set envLocal.path or AGENT_HOME_DIR/CLAUDE_PROJECT_DIR); skipping envLocal target"
    target_env_local="false"
  else
    hook_log "envLocal target path: $ENV_LOCAL_PATH"
  fi
fi

# Prepare settings.local.json writer if needed
if [ "$target_user_settings" = "true" ]; then
  SETTINGS_FILE="${HOME}/.claude/settings.local.json"
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  if [ ! -f "$SETTINGS_FILE" ]; then
    echo '{}' > "$SETTINGS_FILE"
  fi
fi

# --- Process each item ---

# Collect env vars for batch settings.local.json write
declare -a settings_env_names=()
declare -a settings_env_values=()

write_to_targets() {
  local env_name="$1"
  local env_value="$2"

  # Record var NAME in the secrets manifest (not value) so that the PostToolUse
  # redaction hook can look up current values from the env at scan time.
  if [ -n "$_OP_EXEC_MANIFEST" ]; then
    printf '%s\n' "$env_name" >> "$_OP_EXEC_MANIFEST"
  fi

  if [ "$target_bash_env" = "true" ] && [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    # NOTE: kept as append (not upsert) here: CLAUDE_ENV_FILE is session-fresh
    # and op-exec output for a single session is the source of truth.
    printf 'export %s=%q\n' "$env_name" "$env_value" >> "$CLAUDE_ENV_FILE"
  fi

  if [ "$target_env_local" = "true" ] && [ -n "$ENV_LOCAL_PATH" ]; then
    # Idempotent replace-or-append. Multiple sessions / re-runs do not
    # accumulate duplicate or stale entries.
    env_file_upsert_export "$ENV_LOCAL_PATH" "$env_name" "$env_value"
    # On first write, also chain ENV_LOCAL_PATH and its sourceChain into CLAUDE_ENV_FILE.
    if [ "$ENV_LOCAL_SOURCE_CHAIN_WRITTEN" != "true" ]; then
      _chain_env_local_into_claude_env_file "$ENV_LOCAL_PATH"
      hook_log "Chained $ENV_LOCAL_PATH into CLAUDE_ENV_FILE"
      ENV_LOCAL_SOURCE_CHAIN_WRITTEN="true"
    fi
  fi

  if [ "$target_user_settings" = "true" ]; then
    settings_env_names+=("$env_name")
    settings_env_values+=("$env_value")
  fi
}

flush_settings() {
  if [ "$target_user_settings" != "true" ] || [ ${#settings_env_names[@]} -eq 0 ]; then
    return
  fi

  # Build a single jq filter that sets all env vars at once
  local jq_args=()
  local jq_filter=".env += {"
  for i in "${!settings_env_names[@]}"; do
    local arg_key="k${i}"
    local arg_val="v${i}"
    jq_args+=(--arg "$arg_key" "${settings_env_names[$i]}")
    jq_args+=(--arg "$arg_val" "${settings_env_values[$i]}")
    if [ "$i" -gt 0 ]; then
      jq_filter+=", "
    fi
    jq_filter+="(\$${arg_key}): \$${arg_val}"
  done
  jq_filter+="}"

  local result
  if result=$(jq "${jq_args[@]}" "$jq_filter" "$SETTINGS_FILE" 2>/dev/null) && [ -n "$result" ]; then
    echo "$result" > "$SETTINGS_FILE"
  fi
}

process_item() {
  local item_ref="$1"
  op_resolve_item_to_callback "$item_ref" write_to_targets
}

# --- PostToolUse redaction hook setup ---

# Copy redact-secrets.sh from the plugin source to CLAUDE_PLUGIN_DATA so it
# has a stable, version-independent path for the settings.json hook command.
_copy_redact_script() {
  [ -z "${CLAUDE_PLUGIN_ROOT:-}" ] && return 0
  [ -z "${CLAUDE_PLUGIN_DATA:-}" ] && return 0

  local src="${CLAUDE_PLUGIN_ROOT}/hooks/scripts/redact-secrets.sh"
  local dst="${CLAUDE_PLUGIN_DATA}/redact-secrets.sh"

  if [ ! -f "$src" ]; then
    hook_log "WARN: redact-secrets.sh not found at ${src}, PostToolUse hook unavailable"
    return 0
  fi

  cp "$src" "$dst"
  chmod +x "$dst"
  hook_log "synced redact-secrets.sh to plugin data dir"
}

# Register the PostToolUse redaction hook in settings.local.json.
# Plugin-bundled hooks/hooks.json does NOT fire PostToolUse due to an upstream
# bug (https://github.com/anthropics/claude-code/issues/6305). Empirically
# confirmed 2026-05-19: Claude Code v2.1.128 CLI, scm-utils PostToolUse hook
# from hooks.json did not fire on a matching Bash tool call. Remove this
# workaround once #6305 is fixed upstream. This function
# injects the hook directly into settings.local.json so it actually fires.
# The injection is idempotent — re-running this on every SessionStart is safe.
_register_posttooluse_hook() {
  [ -z "${CLAUDE_PLUGIN_DATA:-}" ] && return 0
  command -v jq &>/dev/null || { hook_log "jq not found, skipping PostToolUse hook registration"; return 0; }

  local script="${CLAUDE_PLUGIN_DATA}/redact-secrets.sh"
  [ -f "$script" ] || return 0  # script copy failed — nothing to register

  local hook_command="bash ${script}"
  local settings_file="${HOME}/.claude/settings.local.json"

  mkdir -p "$(dirname "$settings_file")"
  [ -f "$settings_file" ] || echo '{}' > "$settings_file"

  # Idempotent: skip if this exact command is already registered
  if jq -r '.hooks.PostToolUse // [] | .[] | .hooks // [] | .[] | .command // ""' \
       "$settings_file" 2>/dev/null \
     | grep -qxF "$hook_command" 2>/dev/null; then
    hook_log "PostToolUse redaction hook already registered"
    return 0
  fi

  local result
  result=$(jq \
    --arg cmd "$hook_command" \
    '.hooks.PostToolUse = ((.hooks.PostToolUse // []) + [
       {"matcher": "*", "hooks": [{"type": "command", "command": $cmd, "timeout": 5}]}
     ])' \
    "$settings_file" 2>/dev/null) || {
    hook_log "WARN: failed to register PostToolUse hook in ${settings_file}"
    return 0
  }

  if [ -z "$result" ]; then
    hook_log "WARN: jq produced empty result for PostToolUse hook registration"
    return 0
  fi

  # Atomic write: tempfile-then-mv prevents partial writes on crash/signal.
  # shared-lib's safe_write_settings doesn't support extra --arg params yet,
  # so we implement the tempfile pattern directly here.
  local tmp_file
  tmp_file="$(mktemp "${settings_file}.XXXXXXXXXX")"
  if printf '%s\n' "$result" > "$tmp_file" && mv "$tmp_file" "$settings_file"; then
    hook_log "registered PostToolUse redaction hook in ${settings_file}"
  else
    rm -f "$tmp_file"
    hook_log "WARN: failed to write PostToolUse hook to ${settings_file}"
  fi
}

# --- Main ---

do_inject() {
  # Clear manifest from any previous session so this session starts fresh.
  # write_to_targets() appends one name per var as items are resolved below.
  if [ -n "$_OP_EXEC_MANIFEST" ]; then
    : > "$_OP_EXEC_MANIFEST"
  fi

  hook_log_step "init" "Injecting 1Password items as environment"

  local targets_desc=""
  [ "$target_bash_env" = "true" ] && targets_desc="sessionStartBashEnv"
  if [ "$target_env_local" = "true" ]; then
    [ -n "$targets_desc" ] && targets_desc="$targets_desc, "
    targets_desc="${targets_desc}envLocal"
  fi
  if [ "$target_user_settings" = "true" ]; then
    [ -n "$targets_desc" ] && targets_desc="$targets_desc, "
    targets_desc="${targets_desc}userSettings"
  fi
  hook_log "targets: $targets_desc"

  while IFS= read -r item_ref; do
    [ -z "$item_ref" ] && continue
    process_item "$item_ref"
  done <<< "$op_exec_items"

  # Flush collected env vars to settings.local.json in a single write
  flush_settings

  # Copy redact-secrets.sh to plugin data dir and register PostToolUse hook.
  # These are no-ops when CLAUDE_PLUGIN_DATA / CLAUDE_PLUGIN_ROOT are unset.
  hook_log_step "redact-setup" "Setting up PostToolUse secret-redaction hook"
  _copy_redact_script
  _register_posttooluse_hook
}

# --- Execute ---

hook_run do_inject
hook_log_cleanup
hook_respond
