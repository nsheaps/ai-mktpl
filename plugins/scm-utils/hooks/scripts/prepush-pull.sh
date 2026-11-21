#!/usr/bin/env bash
# prepush-pull.sh — Pull before push to keep branch up to date
#
# PreToolUse hook for the Bash tool. When a `git push` command is detected,
# runs `git pull` (with --rebase by default, configurable) to ensure the
# branch is up to date before pushing.
#
# Behavior:
#   - If pull/rebase fails (conflicts), blocks the push with instructions
#   - If pull brought new commits, prints what changed then allows the push
#   - If nothing to pull, stays silent and allows the push
#
# Configuration (via plugins.settings.yaml):
#   scm-utils:
#     prePushPullStrategy: "rebase"  # or "merge"
#
# Exit codes:
#   0 — allow the command (no stdout = defer to default auth)
#   2 — block the command (stdout message shown as rejection)

set -euo pipefail

LOG_PREFIX="scm-utils"
PLUGIN_NAME="scm-utils"

# Resolve plugin root from script location
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=../../lib/log.sh
source "${PLUGIN_ROOT}/lib/log.sh"
# shellcheck source=../../lib/plugin-config-read.sh
source "${PLUGIN_ROOT}/lib/plugin-config-read.sh"

# Read tool input from stdin
input=$(cat)
command=$(echo "$input" | jq -r '.command // empty' 2>/dev/null || true)

# Only care about git push commands
# Match: git push, git -C <path> push, git push origin, git push -u origin branch, etc.
if ! echo "$command" | grep -qE '(^|\s)git\s+(-[A-Za-z]\s+\S+\s+)*push(\s|$)'; then
  exit 0
fi

# Check if we're in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  exit 0
fi

# Get current branch
branch=$(git symbolic-ref --short HEAD 2>/dev/null || true)
if [ -z "$branch" ] || [ "$branch" = "HEAD" ]; then
  exit 0  # Detached HEAD, nothing to do
fi

# Check if branch has an upstream set
if ! git rev-parse --abbrev-ref "@{upstream}" &>/dev/null 2>&1; then
  exit 0  # No upstream configured — likely a first push with -u
fi

# Get configured strategy (default: rebase)
strategy=$(plugin_get_config "prePushPullStrategy" "rebase")

# Record current HEAD before pull
old_head=$(git rev-parse HEAD)

# Pull with configured strategy
# Redirect git's stdout to stderr so hook stdout stays clean for responses
if [ "$strategy" = "rebase" ]; then
  if ! git pull --rebase >&2; then
    git rebase --abort 2>/dev/null || true
    cat <<EOF
BLOCKED: git pull --rebase failed for branch '$branch'.

Your branch has conflicts with the remote that could not be automatically resolved.
Resolve the conflicts manually before pushing.

To resolve:
  git pull --rebase
  # fix conflicts in the listed files
  git add <resolved-files>
  git rebase --continue
  git push
EOF
    exit 2
  fi
  strategy_past="rebased"
else
  if ! git pull >&2; then
    git merge --abort 2>/dev/null || true
    cat <<EOF
BLOCKED: git pull failed for branch '$branch'.

Your branch has merge conflicts with the remote that could not be automatically resolved.
Resolve the conflicts manually before pushing.

To resolve:
  git pull
  # fix conflicts in the listed files
  git add <resolved-files>
  git commit
  git push
EOF
    exit 2
  fi
  strategy_past="merged"
fi

# Check if anything changed
new_head=$(git rev-parse HEAD)

if [ "$old_head" != "$new_head" ]; then
  # Show what was pulled in
  new_commits=$(git log --oneline "${old_head}..${new_head}")
  commit_count=$(echo "$new_commits" | wc -l | tr -d ' ')
  log_info "Branch '${branch}' was out of date — ${strategy_past} ${commit_count} new commit(s) for you. Here's what changed:"
  echo "$new_commits" >&2
fi

# Allow push to proceed (no stdout = defer to default auth)
exit 0
