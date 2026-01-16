#!/usr/bin/env bash
# init-gitignore.sh - Creates .gitignore files in .claude/todos/ and .claude/plans/
# Triggered by SessionStart and UserPromptSubmit hooks

set -euo pipefail

# Determine project directory and plugin root
project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
plugin_root="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"

# Template location
template_file="$plugin_root/templates/gitignore.template"

# Function to create .gitignore from template
create_gitignore() {
  local target_dir="$1"
  local gitignore_file="$target_dir/.gitignore"

  if [ -d "$target_dir" ] || [ -d "$project_dir/.claude" ]; then
    mkdir -p "$target_dir"
    if [ ! -f "$gitignore_file" ]; then
      if [ -f "$template_file" ]; then
        cp "$template_file" "$gitignore_file"
      else
        # Fallback if template not found
        echo "# Ignore all synced files in this directory" > "$gitignore_file"
        echo "*" >> "$gitignore_file"
      fi
    fi
  fi
}

# Create .gitignore in .claude/todos/
create_gitignore "$project_dir/.claude/todos"

# Create .gitignore in .claude/plans/
create_gitignore "$project_dir/.claude/plans"

exit 0
