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

# Script-level tmpdir for secret-bearing tempfiles. EXIT trap ensures cleanup
# on any exit path (normal, error, signal). All tempfiles in process_item()
# are created here so no per-function trap scoping is needed.
_OP_EXEC_TMPDIR="$(mktemp -d)"
trap 'rm -rf "$_OP_EXEC_TMPDIR"' EXIT

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

  if [ "$target_bash_env" = "true" ] && [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    # NOTE: kept as append (not upsert) here: CLAUDE_ENV_FILE is session-fresh
    # and op-exec output for a single session is the source of truth.
    printf 'export %s=%q\n' "$env_name" "$env_value" >> "$CLAUDE_ENV_FILE"
  fi

  if [ "$target_env_local" = "true" ] && [ -n "$ENV_LOCAL_PATH" ]; then
    # Idempotent replace-or-append. Multiple sessions / re-runs do not
    # accumulate duplicate or stale entries.
    env_file_upsert_export "$ENV_LOCAL_PATH" "$env_name" "$env_value"
    # On first write, also chain ENV_LOCAL_PATH (or sourceChain) into CLAUDE_ENV_FILE.
    if [ "$ENV_LOCAL_SOURCE_CHAIN_WRITTEN" != "true" ]; then
      local chain
      chain="$(_resolve_env_local_source_chain "$ENV_LOCAL_PATH")"
      if [ -n "$chain" ] && [ -n "${CLAUDE_ENV_FILE:-}" ]; then
        env_file_upsert_source "$CLAUDE_ENV_FILE" "$chain"
        hook_log "Chained $chain into CLAUDE_ENV_FILE"
      fi
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
  hook_log_step "op-exec" "Resolving item: $item_ref"

  # Validate reference format
  if ! [[ "$item_ref" =~ ^op://[^/]+/[^/]+ ]]; then
    hook_fail "op-exec" "Invalid reference format: $item_ref (expected op://vault/item)" \
      "Check opExec.items in plugin settings"
    return 0
  fi

  # Run op-exec to get export statements
  # Note: op-exec always resolves op:// references recursively (built-in behavior)
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

  # Evaluate op-exec output in a clean subshell to resolve heredocs/complex syntax.
  # op-exec can output heredoc-style assignments (e.g. export VAR=$(cat <<'EOF'...))
  # which break line-by-line parsing. By eval'ing in env -i, only the exported vars
  # appear in the output — no inherited env to filter.
  #
  # We use `env -0` to NUL-delimit records, which correctly handles multi-line
  # values (e.g. PEM keys). NUL bytes can't appear in env values, so this is
  # the only safe delimiter. We read via process substitution because bash
  # strips NULs from $() command substitution output.
  local eval_stderr eval_output
  eval_stderr="$(mktemp -p "$_OP_EXEC_TMPDIR")"
  eval_output="$(mktemp -p "$_OP_EXEC_TMPDIR")"
  local eval_exit=0
  env -i HOME="$HOME" PATH="$PATH" bash -c "
    set -e
    eval \"\$1\"
    env -0
  " _ "$exports" 2>"$eval_stderr" > "$eval_output" || eval_exit=$?

  if [[ $eval_exit -ne 0 ]]; then
    local err_msg=""
    [[ -s "$eval_stderr" ]] && err_msg="$(cat "$eval_stderr")"
    hook_fail "op-exec" "Failed to evaluate op-exec output for: $item_ref${err_msg:+ — $err_msg}" \
      "The op-exec output may contain syntax that bash cannot evaluate"
    rm -f "$eval_stderr" "$eval_output"
    return 0
  fi

  # Log any stderr even on success (diagnostics, not fatal)
  if [[ -s "$eval_stderr" ]]; then
    while IFS= read -r line; do
      hook_log "[eval stderr] $line"
    done < "$eval_stderr"
  fi
  rm -f "$eval_stderr"

  # Parse NUL-delimited KEY=VALUE records from the isolated subshell.
  # This correctly handles multi-line values (e.g. PEM keys with embedded newlines).
  local count=0
  while IFS= read -r -d '' record; do
    [ -z "$record" ] && continue
    local env_name="${record%%=*}"
    local env_value="${record#*=}"
    # Skip vars injected for the isolated bash to work (not from op-exec)
    case "$env_name" in
      HOME|PATH|PWD|OLDPWD|SHLVL|_) continue ;;
    esac
    if [ -n "$env_name" ]; then
      write_to_targets "$env_name" "$env_value"
      count=$((count + 1))
    fi
  done < "$eval_output"
  rm -f "$eval_output"

  hook_log "exported $count env vars from $item_ref"
}

# --- Main ---

do_inject() {
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
}

# --- Execute ---

hook_run do_inject
hook_log_cleanup
hook_respond
