#!/usr/bin/env bash
# init-gitignore.sh - Creates .gitignore files in .claude/todos/ and .claude/plans/
# Triggered by SessionStart and UserPromptSubmit hooks

set -euo pipefail

# Determine project directory
project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# .gitignore content: ignore everything in this directory
gitignore_content="# Ignore all synced files in this directory
*
"

# Create .gitignore in .claude/todos/ if directory exists or will be created
todos_dir="$project_dir/.claude/todos"
if [ -d "$todos_dir" ] || [ -d "$project_dir/.claude" ]; then
  mkdir -p "$todos_dir"
  if [ ! -f "$todos_dir/.gitignore" ]; then
    echo "$gitignore_content" > "$todos_dir/.gitignore"
  fi
fi

# Create .gitignore in .claude/plans/ if directory exists or will be created
plans_dir="$project_dir/.claude/plans"
if [ -d "$plans_dir" ] || [ -d "$project_dir/.claude" ]; then
  mkdir -p "$plans_dir"
  if [ ! -f "$plans_dir/.gitignore" ]; then
    echo "$gitignore_content" > "$plans_dir/.gitignore"
  fi
fi

exit 0
