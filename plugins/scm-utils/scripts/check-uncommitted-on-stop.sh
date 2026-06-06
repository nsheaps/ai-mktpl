#!/usr/bin/env bash
# check-uncommitted-on-stop.sh - Reminds about uncommitted changes when session stops
# Triggered by Stop hook (async — cannot block, only injects feedback)
#
# Exit code 0 = success, stdout/systemMessage shown to Claude
# Exit code 2 = stderr fed back to Claude as feedback

set -euo pipefail

LOG_PREFIX="scm-utils"


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
      echo "[scm-utils] timed out waiting for $SHARED_LIB_DIR/$lib (shared-lib SessionStart copy)" >&2
      exit 1
    fi
    sleep 0.5
  done
}

_wait_for_shared_lib "log.sh"

# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/log.sh"
# Read hook input from stdin (consume it)
cat > /dev/null

# Check if we're in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  exit 0
fi

# Check for uncommitted changes
status_output=$(git status --porcelain 2>/dev/null || true)

if [ -z "$status_output" ]; then
  # No uncommitted changes — also check for unpushed commits
  local_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [ -n "$local_branch" ] && [ "$local_branch" != "HEAD" ]; then
    ahead_count=$(git rev-list --count "@{upstream}..HEAD" 2>/dev/null || echo "0")
    if [ "$ahead_count" -gt 0 ]; then
      log_warn "You have $ahead_count unpushed commit(s) on '$local_branch'. Push before ending this session."
      exit 2
    fi
  fi
  exit 0
fi

# Count changes
change_count=$(echo "$status_output" | wc -l | tr -d ' ')

# Output the file list (porcelain format, NOT full diff)
{
  log_warn "You have $change_count uncommitted change(s). Commit and push before ending this session:"
  echo "" >&2
  echo "$status_output" >&2
  echo "" >&2
  log_info "Run /commit or use git add + git commit + git push to save your work."
}

exit 2
