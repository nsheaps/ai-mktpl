#!/usr/bin/env bash
# init-gitignore.sh - Ensures .claude/todos and .claude/plans are globally ignored
# Triggered by SessionStart and UserPromptSubmit hooks
#
# This approach adds patterns to ~/.config/git/ignore so that:
# 1. All projects automatically ignore these directories
# 2. No per-project .gitignore files needed
# 3. No commits required in each project

set -euo pipefail


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
      echo "[todo-sync] timed out waiting for $SHARED_LIB_DIR/$lib (shared-lib SessionStart copy)" >&2
      exit 1
    fi
    sleep 0.5
  done
}

_wait_for_shared_lib "hook-output.sh"

# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/hook-output.sh"
# Global gitignore location
global_gitignore="$HOME/.config/git/ignore"

# Patterns to ensure are present
patterns=(
  "**/.claude/plans"
  "**/.claude/todos"
)

# Create directory if needed
mkdir -p "$(dirname "$global_gitignore")"

# Create file if it doesn't exist
touch "$global_gitignore"

# Add each pattern if not already present
for pattern in "${patterns[@]}"; do
  if ! grep -qxF "$pattern" "$global_gitignore" 2>/dev/null; then
    echo "$pattern" >> "$global_gitignore"
  fi
done

hook_msg "todo-sync: gitignore patterns configured"
