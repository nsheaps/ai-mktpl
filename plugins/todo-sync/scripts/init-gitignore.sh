#!/usr/bin/env bash
# init-gitignore.sh - Ensures .claude/todos and .claude/plans are globally ignored
# Triggered by SessionStart and UserPromptSubmit hooks
#
# This approach adds patterns to ~/.config/git/ignore so that:
# 1. All projects automatically ignore these directories
# 2. No per-project .gitignore files needed
# 3. No commits required in each project

set -euo pipefail

# Global gitignore location
global_gitignore="$HOME/.config/git/ignore"

# Patterns to ensure are present
patterns=(
  "**/.claude/plans"
  "**/.claude/todos"
)

# Create directory if needed
mkdir -p "$(dirname "$global_gitignore")"

# Create file if it doesn't exist
touch "$global_gitignore"

# Add each pattern if not already present
for pattern in "${patterns[@]}"; do
  if ! grep -qxF "$pattern" "$global_gitignore" 2>/dev/null; then
    echo "$pattern" >> "$global_gitignore"
  fi
done

exit 0
