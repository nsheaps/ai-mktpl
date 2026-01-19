#!/usr/bin/env bash
# init-gitignore.sh - Creates .gitignore files inside todos/ and plans/ directories
# Triggered by SessionStart and UserPromptSubmit hooks
#
# This approach puts the .gitignore inside each directory so that:
# 1. The directories are created automatically
# 2. The .gitignore files don't show up as uncommitted changes
# 3. Git still ignores the contents of these directories

set -euo pipefail

# Determine project directory
project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Directories to manage
managed_dirs=(
  "$project_dir/.claude/todos"
  "$project_dir/.claude/plans"
)

# Content for the .gitignore files
gitignore_content="# Managed by todo-sync plugin (plugins/todo-sync/scripts/init-gitignore.sh)
# Ignore everything in this directory except this .gitignore
*
!.gitignore
"

# Create each directory with its .gitignore
for dir in "${managed_dirs[@]}"; do
  # Create directory if it doesn't exist
  mkdir -p "$dir"

  gitignore_file="$dir/.gitignore"

  # Create or update the .gitignore file
  if [ ! -f "$gitignore_file" ]; then
    echo "$gitignore_content" > "$gitignore_file"
  else
    # Check if it has our marker, update if needed
    if ! grep -qF "Managed by todo-sync plugin" "$gitignore_file" 2>/dev/null; then
      # File exists but isn't ours, prepend our content
      temp_file=$(mktemp)
      echo "$gitignore_content" > "$temp_file"
      cat "$gitignore_file" >> "$temp_file"
      mv "$temp_file" "$gitignore_file"
    fi
  fi
done

exit 0
