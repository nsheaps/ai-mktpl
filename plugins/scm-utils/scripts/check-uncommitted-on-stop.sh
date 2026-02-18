#!/usr/bin/env bash
# check-uncommitted-on-stop.sh - Reminds about uncommitted changes when session stops
# Triggered by Stop hook (async — cannot block, only injects feedback)
#
# Exit code 0 = success, stdout/systemMessage shown to Claude
# Exit code 2 = stderr fed back to Claude as feedback

set -euo pipefail

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
      echo "WARNING: You have $ahead_count unpushed commit(s) on '$local_branch'. Push before ending this session." >&2
      exit 2
    fi
  fi
  exit 0
fi

# Count changes
change_count=$(echo "$status_output" | wc -l | tr -d ' ')

# Output the file list (porcelain format, NOT full diff)
{
  echo "WARNING: You have $change_count uncommitted change(s). Commit and push before ending this session:"
  echo ""
  echo "$status_output"
  echo ""
  echo "Run /commit or use git add + git commit + git push to save your work."
} >&2

exit 2
