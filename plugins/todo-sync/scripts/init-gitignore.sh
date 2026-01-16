#!/usr/bin/env bash
# init-gitignore.sh - Ensures .claude/.gitignore has patterns for todos/ and plans/
# Triggered by SessionStart and UserPromptSubmit hooks

set -euo pipefail

# Determine project directory
project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Target gitignore file
gitignore_file="$project_dir/.claude/.gitignore"

# Comment markers
start_marker="# BEGIN: Managed by todo-sync plugin (plugins/todo-sync/scripts/init-gitignore.sh)"
end_marker="# END: Managed by todo-sync plugin"

# Patterns to ensure are present (between markers)
patterns=(
  "todos/"
  "plans/"
  "!**/.gitkeep"
  "!**/AGENTS.md"
  "!**/CLAUDE.md"
)

# Create .claude directory if it doesn't exist
mkdir -p "$project_dir/.claude"

# Create gitignore if it doesn't exist
if [ ! -f "$gitignore_file" ]; then
  touch "$gitignore_file"
fi

# Check if markers exist
if ! grep -qF "$start_marker" "$gitignore_file" 2>/dev/null; then
  # Markers don't exist, add them with patterns
  {
    echo ""
    echo "$start_marker"
    for pattern in "${patterns[@]}"; do
      echo "$pattern"
    done
    echo "$end_marker"
  } >> "$gitignore_file"
else
  # Markers exist, update content between them
  # Create a temp file
  temp_file=$(mktemp)

  # Read file line by line and rebuild
  in_section=false
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$line" = "$start_marker" ]; then
      echo "$start_marker"
      for pattern in "${patterns[@]}"; do
        echo "$pattern"
      done
      echo "$end_marker"
      in_section=true
    elif [ "$line" = "$end_marker" ]; then
      in_section=false
    elif [ "$in_section" = false ]; then
      echo "$line"
    fi
  done < "$gitignore_file" > "$temp_file"

  # Replace original file
  mv "$temp_file" "$gitignore_file"
fi

exit 0
