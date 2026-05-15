#!/usr/bin/env bash
# sync-todos.sh - Syncs todos and plans from ~/.claude/ to project .claude/
# Triggered by PostToolUse hook on TodoWrite

set -euo pipefail

PLUGIN_NAME="todo-sync"


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

_wait_for_shared_lib "log.sh"

# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/log.sh"
# Check for jq dependency
if ! command -v jq &>/dev/null; then
  log_warn "jq not found, skipping sync"
  exit 0
fi

# Read hook input from stdin
input=$(cat)

# Extract session_id from hook input
session_id=$(echo "$input" | jq -r '.session_id // empty')

if [ -z "$session_id" ]; then
  log_warn "No session_id in hook input, skipping sync"
  exit 0
fi

# Determine project directory
project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Create target directories if they don't exist
mkdir -p "$project_dir/.claude/todos"
mkdir -p "$project_dir/.claude/plans"

# ============================================================================
# SYNC TODOS
# ============================================================================

# Find the todo file for current session in ~/.claude/todos/
# Files are named: {session-id}-agent-{agent-id}.json or just {session-id}.json
global_todos_dir="$HOME/.claude/todos"

if [ -d "$global_todos_dir" ]; then
  # Find files matching this session_id (using while read to handle filenames with spaces)
  find "$global_todos_dir" -name "${session_id}*.json" -type f 2>/dev/null | while IFS= read -r src_file; do
    filename=$(basename "$src_file")
    dest_file="$project_dir/.claude/todos/$filename"

    # Read source todos
    src_content=$(cat "$src_file" 2>/dev/null || echo "[]")

    # Skip empty arrays
    if [ "$src_content" = "[]" ]; then
      continue
    fi

    # Check if destination exists for merge
    if [ -f "$dest_file" ]; then
      dest_content=$(cat "$dest_file" 2>/dev/null || echo "[]")

      # Merge: combine arrays, remove duplicates by content field
      merged=$(jq -s '
        .[0] + .[1] |
        unique_by(.content // .)
      ' <(echo "$dest_content") <(echo "$src_content"))

      echo "$merged" > "$dest_file"
    else
      # No destination file, just copy
      cp "$src_file" "$dest_file"
    fi
  done
fi

# ============================================================================
# SYNC PLANS
# ============================================================================

global_plans_dir="$HOME/.claude/plans"

if [ -d "$global_plans_dir" ]; then
  # Sync all plan files (they're markdown, so we just copy newer versions)
  for src_file in "$global_plans_dir"/*.md; do
    [ -f "$src_file" ] || continue

    filename=$(basename "$src_file")
    dest_file="$project_dir/.claude/plans/$filename"

    # Only copy if source is newer or destination doesn't exist
    if [ ! -f "$dest_file" ] || [ "$src_file" -nt "$dest_file" ]; then
      cp "$src_file" "$dest_file"
    fi
  done
fi

# Output success message (shown in transcript)
log_info "Synced todos and plans to $project_dir/.claude/"

exit 0
