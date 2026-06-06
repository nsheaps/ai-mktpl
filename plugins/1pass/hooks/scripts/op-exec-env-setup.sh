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
# shellcheck source=/dev/null
source "${CLAUDE_PLUGIN_ROOT}/lib/resolve-op-env.sh"

# Script-level tmpdir for secret-bearing tempfiles. EXIT trap ensures cleanup
# on any exit path (normal, error, signal).
_OP_EXEC_TMPDIR="$(mktemp -d)"
trap 'rm -rf "$_OP_EXEC_TMPDIR"' EXIT

# _OP_EXEC_CONCEALED_FILE is intentionally NOT set here.
# The Setup hook only writes envLocal at plugin install/update time; it does not
# own the redaction manifest (.env.secrets). SessionStart owns that file and
# rewrites it from scratch on every session start. Redaction is session-scoped and
# will always be correctly initialized before any tool calls fire.

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
  hook_log "AGENT_HOME_DIR not set and no envLocal.path configured — skipping Setup write (SessionStart will retry when AGENT_HOME_DIR is available)"
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

# --- Main: resolve items and write envLocal via per-var upsert ---

_setup_total_count=0
_setup_emit() {
  local env_name="$1" env_value="$2"
  env_file_upsert_export "$ENV_LOCAL_PATH" "$env_name" "$env_value"
  _setup_total_count=$((_setup_total_count + 1))
}

do_setup() {
  hook_log_step "init" "Writing envLocal: $ENV_LOCAL_PATH"
  mkdir -p "$(dirname "$ENV_LOCAL_PATH")"

  while IFS= read -r item_ref; do
    [ -z "$item_ref" ] && continue
    op_resolve_item_to_callback "$item_ref" _setup_emit
  done <<< "$op_exec_items"

  if [ "$_setup_total_count" -eq 0 ]; then
    hook_log "no env vars resolved — skipping envLocal write"
    return 0
  fi

  hook_log "wrote $_setup_total_count env vars → $ENV_LOCAL_PATH"
}

# --- Execute ---

hook_run do_setup
hook_log_cleanup
hook_respond
