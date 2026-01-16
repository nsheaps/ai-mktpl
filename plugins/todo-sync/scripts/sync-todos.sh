#!/usr/bin/env bash
# sync-todos.sh - Syncs todos and plans from ~/.claude/ to project .claude/
# Triggered by PostToolUse hook on TodoWrite

set -euo pipefail

# Check for jq dependency
if ! command -v jq &>/dev/null; then
  echo "Warning: jq not found, skipping sync" >&2
  exit 0
fi

# Read hook input from stdin
input=$(cat)

# Extract session_id from hook input
session_id=$(echo "$input" | jq -r '.session_id // empty')

if [ -z "$session_id" ]; then
  echo "No session_id in hook input, skipping sync" >&2
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
echo "Synced todos and plans to $project_dir/.claude/"

exit 0
