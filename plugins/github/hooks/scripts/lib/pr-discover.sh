#!/usr/bin/env bash
# pr-discover.sh — Discover active PRs for the current session's projects
#
# Supports multi-project sessions by scanning CLAUDE_PROJECT_DIR and
# any additional project directories for git repos with active PRs.
#
# Usage:
#   source "${SCRIPT_DIR}/lib/pr-discover.sh"
#   pr_discover_all   # prints "owner repo pr_number" lines to stdout

# Guard against double-sourcing
if [ "${_PR_DISCOVER_LOADED:-}" = "true" ]; then
  return 0 2>/dev/null || true
fi
_PR_DISCOVER_LOADED="true"

# Discover PRs for all projects in the current session.
# Checks CLAUDE_PROJECT_DIR and scans for sibling project dirs
# that are git repos on branches with open PRs.
# Output: "owner repo pr_number" lines on stdout
pr_discover_all() {
  local dirs=()

  # Primary project directory
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    dirs+=("$CLAUDE_PROJECT_DIR")
  fi

  # Multi-project: check parent directory for sibling repos
  # Claude Code web sessions with multiple repos clone them as siblings
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    local parent_dir
    parent_dir="$(dirname "$CLAUDE_PROJECT_DIR")"
    for sibling in "$parent_dir"/*/; do
      [ -d "$sibling" ] || continue
      local abs_sibling
      abs_sibling="$(cd "$sibling" && pwd)"
      # Skip the primary project (already added)
      [ "$abs_sibling" = "$CLAUDE_PROJECT_DIR" ] && continue
      # Only include git repos
      [ -d "$abs_sibling/.git" ] && dirs+=("$abs_sibling")
    done
  fi

  # For each directory, find the current branch's PR
  for dir in "${#dirs[@]+${dirs[@]}}"; do
    [ -d "$dir/.git" ] || continue
    _pr_discover_for_dir "$dir"
  done
}

# Discover PRs for a single directory.
# Args: $1=directory
# Output: "owner repo pr_number" on stdout (one per PR found)
_pr_discover_for_dir() {
  local dir="$1"
  local branch remote_url owner repo pr_number

  # Get current branch
  branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)" || return 0
  [ "$branch" = "HEAD" ] && return 0
  [ "$branch" = "main" ] || [ "$branch" = "master" ] && return 0

  # Get remote URL and extract owner/repo
  remote_url="$(git -C "$dir" config --get remote.origin.url 2>/dev/null)" || return 0
  _pr_extract_owner_repo "$remote_url" || return 0

  # Find open PR for this branch
  local gh_hostname_flag=""
  if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]; then
    gh_hostname_flag="--hostname github.com"
  fi

  pr_number="$(gh api ${gh_hostname_flag} \
    "repos/${_PR_OWNER}/${_PR_REPO}/pulls?head=${_PR_OWNER}:${branch}&state=open" \
    --jq '.[0].number // empty' 2>/dev/null)" || return 0

  if [ -n "$pr_number" ]; then
    echo "${_PR_OWNER} ${_PR_REPO} ${pr_number}"
  fi
}

# Internal variables for owner/repo extraction
_PR_OWNER=""
_PR_REPO=""

# Extract owner and repo from a git remote URL.
# Supports HTTPS and SSH formats, including local proxy URLs.
# Args: $1=remote_url
# Sets: _PR_OWNER, _PR_REPO
# Returns: 0 on success, 1 on failure
_pr_extract_owner_repo() {
  local url="$1"
  _PR_OWNER=""
  _PR_REPO=""

  # Handle various URL formats:
  # https://github.com/owner/repo.git
  # git@github.com:owner/repo.git
  # http://127.0.0.1:PORT/git/owner/repo (web session proxy)
  if echo "$url" | grep -qE '/git/[^/]+/[^/]+$'; then
    # Web session proxy format
    _PR_OWNER="$(echo "$url" | sed 's|.*/git/\([^/]*\)/\([^/]*\)$|\1|')"
    _PR_REPO="$(echo "$url" | sed 's|.*/git/\([^/]*\)/\([^/]*\)$|\2|' | sed 's/\.git$//')"
  elif echo "$url" | grep -qE 'github\.com[:/]'; then
    # Standard GitHub URL
    _PR_OWNER="$(echo "$url" | sed 's|.*github\.com[:/]\([^/]*\)/.*|\1|')"
    _PR_REPO="$(echo "$url" | sed 's|.*github\.com[:/][^/]*/\([^/]*\)$|\1|' | sed 's/\.git$//')"
  else
    return 1
  fi

  [ -n "$_PR_OWNER" ] && [ -n "$_PR_REPO" ]
}
