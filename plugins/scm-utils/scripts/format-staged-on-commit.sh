#!/usr/bin/env bash
# format-staged-on-commit.sh — Auto-format staged files before git commit
#
# PreToolUse hook for the Bash tool. Intercepts `git commit` commands,
# runs prettier on staged files, and re-stages them so commits are
# always properly formatted. Prevents CI from wasting cycles pushing
# formatting fixes back to PRs.
#
# NOTE: This re-stages the entire file after formatting. If you used
# `git add -p` for partial staging, the unstaged hunks will also be staged.
# This is acceptable for AI-agent-driven workflows where partial staging is rare.
#
# Exit codes:
#   0 — allow the command (after formatting)

set -euo pipefail

input=$(cat)

command=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

# Only care about git commit commands
if ! echo "$command" | grep -qE '(^|\s)git\s+(-[A-Za-z]\s+\S+\s+)*commit(\s|$)'; then
  echo '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
  exit 0
fi

# Check if prettier is available
if ! command -v prettier &>/dev/null; then
  echo "prettier not found, skipping pre-commit format" >&2
  echo '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
  exit 0
fi

# Get staged files (excluding deleted)
staged=$(git diff --cached --name-only --diff-filter=d 2>/dev/null || true)
if [ -z "$staged" ]; then
  echo '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
  exit 0
fi

# Let prettier decide what it can format — run --check on each staged file
# and only format those that prettier recognizes and finds unformatted.
# This avoids maintaining a hardcoded extension list that drifts from .prettierrc.
formatted=0
while IFS= read -r file; do
  [ -f "$file" ] || continue
  if ! prettier --check "$file" &>/dev/null; then
    # prettier returns non-zero for both "unformatted" and "unsupported" files.
    # Try to format — prettier --write silently skips unsupported files.
    if prettier --write "$file" >/dev/null 2>&1; then
      git add "$file"
      formatted=$((formatted + 1))
      echo "[scm-utils] Formatted: $file" >&2
    fi
  fi
done <<< "$staged"

if [ "$formatted" -gt 0 ]; then
  echo "[scm-utils] Auto-formatted $formatted file(s) before commit" >&2
fi

echo '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
exit 0
