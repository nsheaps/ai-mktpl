#!/usr/bin/env bash
# Claude Code statusline script with iTerm2 badge integration
# Based on: stainless-api/stainless/.mise/tasks/claude-statusline
set -e

# Prevent git from creating lock files for read-only operations
export GIT_OPTIONAL_LOCKS=0

# Set an iTerm2 user variable (for badge display)
# Usage: iterm2_set_user_var <name> <value>
iterm2_set_user_var() {
  if [ "$TERM_PROGRAM" = "iTerm.app" ]; then
    printf "\033]1337;SetUserVar=%s=%s\007" "$1" "$(echo -n "$2" | base64)" >&2
  fi
}

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

PR_URL_OR_EMPTY="$(gh pr view --json url -q .url 2>/dev/null || echo "")"
REPO_URL="$(gh repo view --json url -q .url 2>/dev/null || echo "")"
PR_OR_BRANCH_OR_REPO_URL_FROM_GH="${PR_URL_OR_EMPTY:-$REPO_URL}"

# Project/cwd info
if [ "$cwd" = "$project_dir" ]; then
  echo "In: $project_dir_relative_to_home | $PR_OR_BRANCH_OR_REPO_URL_FROM_GH"
else
  echo "In: $project_dir_relative_to_home | In: $cwd_relative_to_project | $PR_OR_BRANCH_OR_REPO_URL_FROM_GH"
fi

# Git status (handles both regular repos and worktrees)
# Also builds iTerm badge text
badge_text=""
if [ -d "$project_dir/.git" ] || [ -f "$project_dir/.git" ]; then
  repo_org_name=$(git -C "$project_dir" config --get remote.origin.url 2>/dev/null | sed -E 's|.*/([^/]+/[^/]+)(\.git)?$|\1|' | sed 's/\.git$//' || echo "")
  branch=$(git -C "$project_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
  changes=$(git -C "$project_dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

  # Statusline output
  if [ "$changes" = "0" ]; then
    echo "On: $repo_org_name@$branch (clean)"
  else
    echo "On: $repo_org_name@$branch ($changes changes)"
  fi

  # Build iTerm badge text
  # Line 1: owner/repo
  badge_text="$repo_org_name"

  # Line 2: branch + ahead/behind + clean/dirty
  git_info="$branch"

  # Get ahead/behind counts
  upstream=$(git -C "$project_dir" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo "")
  if [ -n "$upstream" ]; then
    ahead=$(git -C "$project_dir" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo "0")
    behind=$(git -C "$project_dir" rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo "0")
    [ "$ahead" -gt 0 ] 2>/dev/null && git_info="$git_info ↑$ahead"
    [ "$behind" -gt 0 ] 2>/dev/null && git_info="$git_info ↓$behind"
  fi

  # Clean/dirty indicator
  if [ "$changes" = "0" ]; then
    git_info="$git_info ✓"
  else
    git_info="$git_info ✗"
  fi

  badge_text="$badge_text
$git_info"
elif [[ "$cwd" == "$HOME/src/"* ]]; then
  # In ~/src but not a git repo - show org/folder structure
  badge_text="${cwd#$HOME/src/}"
fi

# Set iTerm2 badge
iterm2_set_user_var "badge" "$badge_text"

# par-cc-usage statusline (strip project name prefix)
pccu_status="$(echo "$input" | uvx --from par-cc-usage pccu statusline 2>/dev/null | sed 's/^\[.*\] - //' || true)"
if [ -n "$pccu_status" ]; then
  echo "$pccu_status"
fi
