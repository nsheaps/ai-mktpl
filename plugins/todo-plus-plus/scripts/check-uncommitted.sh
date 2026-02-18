#!/usr/bin/env bash
# check-uncommitted.sh - Blocks task completion if there are uncommitted changes
# Triggered by TaskCompleted hook
#
# Exit code 2 = block completion and send stderr as feedback to Claude
# Exit code 0 = allow completion

set -euo pipefail

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

  echo "BLOCKED: You have $change_count uncommitted change(s). Commit and push your work before marking this task complete. Run 'git status' to see what needs to be committed." >&2
  exit 2
fi

# Check if local branch is ahead of remote
local_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [ -n "$local_branch" ] && [ "$local_branch" != "HEAD" ]; then
  ahead_count=$(git rev-list --count "@{upstream}..HEAD" 2>/dev/null || echo "0")
  if [ "$ahead_count" -gt 0 ]; then
    echo "BLOCKED: You have $ahead_count unpushed commit(s) on '$local_branch'. Push your changes before marking this task complete." >&2
    exit 2
  fi
fi

# All clear
exit 0
