#!/usr/bin/env bash
# check-uncommitted.sh - Blocks task completion if there are uncommitted changes
# Triggered by TaskCompleted hook
#
# Exit code 2 = block completion and send stderr as feedback to Claude
# Exit code 0 = allow completion

set -euo pipefail

LOG_PREFIX="todo-plus-plus"


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
      echo "[todo-plus-plus] timed out waiting for $SHARED_LIB_DIR/$lib (shared-lib SessionStart copy)" >&2
      exit 1
    fi
    sleep 0.5
  done
}

_wait_for_shared_lib "log.sh"

# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/log.sh"
# Read hook input from stdin (consume it so the pipe doesn't break)
cat > /dev/null

# Check if we're in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  # Not a git repo, allow completion
  exit 0
fi

# Check for uncommitted changes (staged + unstaged + untracked)
status_output=$(git status --porcelain 2>/dev/null || true)

if [ -n "$status_output" ]; then
  # Count the changes
  change_count=$(echo "$status_output" | wc -l | tr -d ' ')

  log_error "BLOCKED: You have $change_count uncommitted change(s). Commit and push your work before marking this task complete. Run 'git status' to see what needs to be committed."
  exit 2
fi

# Check if local branch is ahead of remote
local_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [ -n "$local_branch" ] && [ "$local_branch" != "HEAD" ]; then
  ahead_count=$(git rev-list --count "@{upstream}..HEAD" 2>/dev/null || echo "0")
  if [ "$ahead_count" -gt 0 ]; then
    log_error "BLOCKED: You have $ahead_count unpushed commit(s) on '$local_branch'. Push your changes before marking this task complete."
    exit 2
  fi
fi

# All clear
exit 0
