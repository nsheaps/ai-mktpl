#!/usr/bin/env bash
# reject-git-push.sh — Reject `git push` on git-spice tracked branches
#
# PreToolUse hook for the Bash tool. Reads the tool input JSON from stdin,
# checks if the command is `git push`, and if the current branch is tracked
# by git-spice, rejects the push with a message to use `gs stack submit`.
#
# Exit codes:
#   0 — allow the command
#   2 — block the command (non-zero rejects PreToolUse)

set -euo pipefail

# Read tool input from stdin
input=$(cat)

# Extract the command from the JSON input
command=$(echo "$input" | jq -r '.command // empty' 2>/dev/null || true)

# Only care about git push commands
# Match: git push, git -C <path> push, git push origin, git push -u origin branch, etc.
if ! echo "$command" | grep -qE '(^|\s)git\s+(-[A-Za-z]\s+\S+\s+)*push(\s|$)'; then
  exit 0
fi

# Check if git-spice is installed
if ! command -v gs &>/dev/null; then
  exit 0
fi

# Check if we're in a git repo with git-spice initialized
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  exit 0
fi

# Get current branch name
branch=$(git symbolic-ref --short HEAD 2>/dev/null || true)
if [ -z "$branch" ]; then
  # Detached HEAD — not a tracked branch
  exit 0
fi

# Check if the repo is initialized with git-spice
# gs log short exits non-zero if not initialized
if ! gs log short &>/dev/null; then
  exit 0
fi

# Check if the current branch is tracked by git-spice
# gs log short lists tracked branches — grep for the current branch name
if ! gs log short 2>/dev/null | grep -qF "$branch"; then
  # Not tracked by git-spice — allow the push
  exit 0
fi

# Branch IS tracked by git-spice — reject the push
cat <<EOF
BLOCKED: Branch '$branch' is tracked by git-spice.

Do not use \`git push\` on git-spice tracked branches. It bypasses
git-spice's stacking model and creates incorrect PR relationships.

Instead, use:
  gs stack submit    # (gs ss) — submit/update all PRs in the stack
  gs branch submit   # (gs bs) — submit/update just this branch's PR

If you need to force push for a rebase, use:
  gs stack submit    # handles force-push internally
EOF

exit 2
