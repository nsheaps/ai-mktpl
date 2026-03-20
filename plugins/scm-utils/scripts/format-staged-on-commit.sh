#!/usr/bin/env bash
# format-staged-on-commit.sh — Auto-format staged files before git commit
#
# PreToolUse hook for the Bash tool. Intercepts `git commit` commands,
# runs prettier on staged files, and re-stages them so commits are
# always properly formatted. Prevents CI from wasting cycles pushing
# formatting fixes back to PRs.
#
# Exit codes:
#   0 — allow the command (after formatting)

set -euo pipefail

input=$(cat)

command=$(echo "$input" | jq -r '.command // empty' 2>/dev/null || true)

# Only care about git commit commands
if ! echo "$command" | grep -qE '(^|\s)git\s+(-[A-Za-z]\s+\S+\s+)*commit(\s|$)'; then
  exit 0
fi

# Check if prettier is available
if ! command -v prettier &>/dev/null; then
  echo "prettier not found, skipping pre-commit format" >&2
  exit 0
fi

# Get staged files (excluding deleted)
staged=$(git diff --cached --name-only --diff-filter=d 2>/dev/null || true)
if [ -z "$staged" ]; then
  exit 0
fi

# Filter to files prettier can handle
files_to_format=()
while IFS= read -r file; do
  case "$file" in
    *.json|*.yaml|*.yml|*.md|*.js|*.ts|*.jsx|*.tsx|*.css|*.html)
      [ -f "$file" ] && files_to_format+=("$file")
      ;;
  esac
done <<< "$staged"

if [ ${#files_to_format[@]} -eq 0 ]; then
  exit 0
fi

formatted=0
for file in "${files_to_format[@]}"; do
  if ! prettier --check "$file" &>/dev/null; then
    prettier --write "$file" >/dev/null 2>&1
    git add "$file"
    formatted=$((formatted + 1))
    echo "[scm-utils] Formatted: $file" >&2
  fi
done

if [ "$formatted" -gt 0 ]; then
  echo "[scm-utils] Auto-formatted $formatted file(s) before commit" >&2
fi

exit 0
