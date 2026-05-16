#!/usr/bin/env bash
# op-exec-env-setup.sh — Setup{init} hook for writing $AGENT_HOME_DIR/.env.local
#
# Fires at plugin install/update time (Setup trigger: "init"). Resolves the
# configured opExec items and writes them to the envLocal target so the file
# is available before the first SessionStart hook runs.
#
# Requires AGENT_HOME_DIR to be set in the hook environment; if unset, logs a
# notice and exits cleanly (SessionStart will populate envLocal instead).
#
# Only runs when:
#   - The plugin is enabled
#   - opExec.items is non-empty
#   - "envLocal" is in opExec.targets
#   - op-exec and op are both on PATH
#   - AGENT_HOME_DIR is set in the hook environment
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

# Wait up to ~10s for a shared-lib file to appear (handles parallel hook
# ordering where shared-lib's copy may not have completed yet).
_wait_for_shared_lib() {
  local lib="$1"
  local i=0
  while [ ! -f "$SHARED_LIB_DIR/$lib" ]; do
    i=$((i + 1))
    if [ "$i" -ge 20 ]; then
      echo "[1pass] timed out waiting for $SHARED_LIB_DIR/$lib (shared-lib copy)" >&2
      exit 1
    fi
    sleep 0.5
  done
}

_wait_for_shared_lib "plugin-config-read.sh"
_wait_for_shared_lib "hook-logging.sh"
_wait_for_shared_lib "env-file.sh"
_wait_for_shared_lib "env-local-target.sh"

# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/plugin-config-read.sh"
# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/hook-logging.sh"
# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/env-file.sh"
# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/env-local-target.sh"

# Script-level tmpdir for secret-bearing tempfiles. EXIT trap ensures cleanup
# on any exit path (normal, error, signal).
_OP_EXEC_TMPDIR="$(mktemp -d)"
trap 'rm -rf "$_OP_EXEC_TMPDIR"' EXIT

# --- Guards ---

plugin_is_enabled || { hook_log "plugin disabled, skipping op-exec env setup"; hook_respond; exit 0; }

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

# --- Check if envLocal target is requested ---

target_env_local="false"
while IFS= read -r target; do
  case "$target" in
    envLocal) target_env_local="true" ;;
  esac
done <<< "$op_exec_targets"

if [ "$target_env_local" != "true" ]; then
  hook_log "envLocal not in opExec.targets — nothing to do at setup time"
  hook_respond
  exit 0
fi

# --- Resolve envLocal path ---

ENV_LOCAL_PATH="$(_resolve_env_local_path)"
if [ -z "$ENV_LOCAL_PATH" ]; then
  hook_log "[1pass] AGENT_HOME_DIR not set and no envLocal.path configured — skipping Setup write (SessionStart will retry when AGENT_HOME_DIR is available)"
  hook_respond
  exit 0
fi

# --- Dependency checks ---

if ! command -v op-exec &>/dev/null; then
  hook_log "op-exec not found on PATH — skipping Setup write (SessionStart will retry after install)"
  hook_respond
  exit 0
fi

if ! command -v op &>/dev/null; then
  hook_log "1Password CLI (op) not found on PATH — skipping Setup write (SessionStart will retry after install)"
  hook_respond
  exit 0
fi

# --- Main: resolve items and write envLocal atomically ---

do_setup() {
  hook_log_step "init" "Writing envLocal: $ENV_LOCAL_PATH"

  # Accumulate all export lines into a single tmpfile, then mv atomically.
  local tmpfile
  tmpfile="$(mktemp -p "$_OP_EXEC_TMPDIR")"
  chmod 600 "$tmpfile"

  local total_count=0

  while IFS= read -r item_ref; do
    [ -z "$item_ref" ] && continue

    hook_log_step "op-exec" "Resolving item: $item_ref"

    if ! [[ "$item_ref" =~ ^op://[^/]+/[^/]+ ]]; then
      hook_fail "op-exec" "Invalid reference format: $item_ref (expected op://vault/item)" \
        "Check opExec.items in plugin settings"
      continue
    fi

    local exports
    if ! exports="$(op-exec "$item_ref" 2>/dev/null)"; then
      hook_fail "op-exec" "Failed to resolve item: $item_ref" \
        "Verify the item exists and op has access to the vault"
      continue
    fi

    if [ -z "$exports" ]; then
      hook_log "no fields found in $item_ref"
      continue
    fi

    # Evaluate op-exec output in a clean subshell (same pattern as op-exec-env.sh)
    # to handle heredoc-style assignments and multi-line values safely.
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
      continue
    fi

    if [[ -s "$eval_stderr" ]]; then
      while IFS= read -r line; do
        hook_log "[eval stderr] $line"
      done < "$eval_stderr"
    fi
    rm -f "$eval_stderr"

    local count=0
    while IFS= read -r -d '' record; do
      [ -z "$record" ] && continue
      local env_name="${record%%=*}"
      local env_value="${record#*=}"
      case "$env_name" in
        HOME|PATH|PWD|OLDPWD|SHLVL|_) continue ;;
      esac
      if [ -n "$env_name" ]; then
        printf 'export %s=%q\n' "$env_name" "$env_value" >> "$tmpfile"
        count=$((count + 1))
      fi
    done < "$eval_output"
    rm -f "$eval_output"

    hook_log "resolved $count env vars from $item_ref"
    total_count=$((total_count + count))
  done <<< "$op_exec_items"

  if [ "$total_count" -eq 0 ]; then
    hook_log "no env vars resolved — skipping envLocal write"
    rm -f "$tmpfile"
    return 0
  fi

  # Atomic rename to final path
  mkdir -p "$(dirname "$ENV_LOCAL_PATH")"
  mv "$tmpfile" "$ENV_LOCAL_PATH"
  hook_log "wrote $total_count env vars → $ENV_LOCAL_PATH"
}

# --- Execute ---

hook_run do_setup
hook_log_cleanup
hook_respond
