#!/usr/bin/env bash
# configure-permissions.sh — SessionStart hook for sequential-thinking plugin
#
# Adds "mcp__sequential-thinking__*" to the allow list in settings.local.json
# so all sequential-thinking MCP tools are auto-approved without prompts.
#
# Uses the shared add-permission library for idempotent, atomic updates.
set -euo pipefail

PLUGIN_NAME="sequential-thinking"

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
      echo "[sequential-thinking] timed out waiting for $SHARED_LIB_DIR/$lib (shared-lib SessionStart copy)" >&2
      exit 1
    fi
    sleep 0.5
  done
}

_wait_for_shared_lib "safe-settings-write.sh"
_wait_for_shared_lib "add-permission.sh"
_wait_for_shared_lib "hook-logging.sh"

# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/safe-settings-write.sh"
# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/add-permission.sh"
# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/hook-logging.sh"
SETTINGS_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/settings.local.json"

hook_log_step "add-permission" "Adding sequential-thinking MCP permissions"

if ! add_permission_to_allow "mcp__sequential-thinking__*"; then
  hook_fail "permission setup" "Failed to add mcp__sequential-thinking__* to allow list in $SETTINGS_FILE" \
    "Check file permissions on $SETTINGS_FILE, or verify jq is available"
  hook_respond; exit 0
fi

hook_log "permissions configured"
hook_log_cleanup
hook_respond
