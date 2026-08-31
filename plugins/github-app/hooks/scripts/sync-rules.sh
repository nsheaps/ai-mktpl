#!/usr/bin/env bash
# sync-rules.sh — SessionStart hook for github-app plugin
#
# Creates a symlink at .claude/rules/github-app pointing to this plugin's
# rules/ directory, making all rules available as Claude Code context.
set -euo pipefail

PLUGIN_NAME="github-app"

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
      echo "[github-app] timed out waiting for $SHARED_LIB_DIR/$lib (shared-lib SessionStart copy)" >&2
      exit 1
    fi
    sleep 0.5
  done
}

_wait_for_shared_lib "hook-logging.sh"

# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/hook-logging.sh"
PLUGIN_RULES_DIR="${CLAUDE_PLUGIN_ROOT}/rules"
LINK_NAME="github-app"

# --- Determine target directory ---

PROJECT_RULES_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/rules"
link_path="${PROJECT_RULES_DIR}/${LINK_NAME}"

mkdir -p "$PROJECT_RULES_DIR"

# Remove stale symlink if present
if [ -L "$link_path" ]; then
  rm -f "$link_path"
elif [ -d "$link_path" ]; then
  hook_log_always "WARNING: ${link_path} is a real directory, not replacing — remove manually if unintentional"
  hook_respond
  exit 0
fi

if ! ln -s "$PLUGIN_RULES_DIR" "$link_path"; then
  hook_fail "symlink creation" "Failed to create symlink ${link_path} -> ${PLUGIN_RULES_DIR}" \
    "Check directory permissions for ${PROJECT_RULES_DIR}"
  hook_respond
  exit 0
fi

hook_log "linked ${link_path} -> ${PLUGIN_RULES_DIR}"
hook_log_cleanup
hook_respond
