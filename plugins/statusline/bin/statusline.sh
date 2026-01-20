#!/usr/bin/env bash
# Claude Code statusline script
# Source: stainless-api/stainless/.mise/tasks/claude-statusline
set -e

# Prevent git from creating lock files for read-only operations
export GIT_OPTIONAL_LOCKS=0

# Read JSON input from stdin if available, otherwise empty
input=""
if [ ! -t 0 ]; then
  input="$(cat)"
fi

# Extract project_dir: prefer CLAUDE_PROJECT_DIR, then JSON input, then git root
project_dir="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$project_dir" ] && [ -n "$input" ]; then
  project_dir="$(echo "$input" | jq -r '.workspace.project_dir // empty' 2>/dev/null)"
fi
if [ -z "$project_dir" ]; then
  project_dir="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
fi

# Extract cwd: prefer JSON input, then MISE_ORIGINAL_CWD, then PWD
cwd=""
if [ -n "$input" ]; then
  cwd="$(echo "$input" | jq -r '.workspace.current_dir // empty' 2>/dev/null)"
fi
cwd="${cwd:-${MISE_ORIGINAL_CWD:-$PWD}}"

# Format paths for display

cwd_relative_to_project="${cwd/#$project_dir/.}"
project_dir_relative_to_home="${project_dir/#$HOME/\~}"

# Extract session ID from JSON input
session_id=""
if [ -n "$input" ]; then
  session_id="$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)"
fi

# Session ID (if available)
if [ -n "$session_id" ]; then
  echo "Session: $session_id"
fi

PR_URL_OR_EMPTY="$(cd "$project_dir" && gh pr view --json url -q .url 2>/dev/null || echo "")"
REPO_URL="$(cd "$project_dir" && gh repo view --json url -q .url 2>/dev/null || echo "")"
PR_OR_BRANCH_OR_REPO_URL_FROM_GH="${PR_URL_OR_EMPTY:-$REPO_URL}"

# Project/cwd info
if [ "$cwd" = "$project_dir" ]; then
  echo "In: $project_dir_relative_to_home | $PR_OR_BRANCH_OR_REPO_URL_FROM_GH"
else
  echo "In: $project_dir_relative_to_home | In: $cwd_relative_to_project | $PR_OR_BRANCH_OR_REPO_URL_FROM_GH"
fi

# Git status (handles both regular repos and worktrees)
if [ -d "$project_dir/.git" ] || [ -f "$project_dir/.git" ]; then
  repo_org_name=$(git -C "$project_dir" config --get remote.origin.url 2>/dev/null | sed -E 's|.*/([^/]+/[^/]+)(\.git)?$|\1|' | sed 's/\.git$//' || echo "")
  branch=$(git -C "$project_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
  changes=$(git -C "$project_dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [ "$changes" = "0" ]; then
    echo "On: $repo_org_name@$branch (clean)"
  else
    echo "On: $repo_org_name@$branch ($changes changes)"
  fi
fi

# par-cc-usage statusline (strip project name prefix)
pccu_status="$(echo "$input" | uvx --from par-cc-usage pccu statusline 2>/dev/null | sed 's/^\[.*\] - //' || true)"
if [ -n "$pccu_status" ]; then
  echo "$pccu_status"
fi
