#!/usr/bin/env bash
# init-gitignore.sh - Ensures .claude/.gitignore has patterns for todos/ and plans/
# Triggered by SessionStart and UserPromptSubmit hooks

set -euo pipefail

# Determine project directory
project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Target gitignore file
gitignore_file="$project_dir/.claude/.gitignore"

# Patterns to ensure are present (in order)
patterns=(
  "todos/"
  "plans/"
  "!todos/**/.gitkeep"
  "!todos/**/AGENTS.md"
  "!todos/**/CLAUDE.md"
  "!plans/**/.gitkeep"
  "!plans/**/AGENTS.md"
  "!plans/**/CLAUDE.md"
)

# Function to check if a pattern exists in gitignore
pattern_exists() {
  local pattern="$1"
  local file="$2"

  # Remove trailing slash for comparison (git treats them the same)
  local pattern_no_slash="${pattern%/}"

  # Escape special regex characters in pattern for grep (including !, *, etc.)
  local escaped_pattern=$(printf '%s\n' "$pattern_no_slash" | sed 's/[[\.*^$/!]/\\&/g')

  # Check if pattern exists with or without trailing slash (allowing for comments and whitespace)
  grep -qE "^[[:space:]]*${escaped_pattern}/?[[:space:]]*(#.*)?$" "$file" 2>/dev/null
}

# Function to add pattern to gitignore if it doesn't exist
ensure_pattern() {
  local pattern="$1"
  local file="$2"

  if ! pattern_exists "$pattern" "$file"; then
    # Check if file ends with newline
    if [ -s "$file" ] && [ -n "$(tail -c 1 "$file")" ]; then
      echo "" >> "$file"
    fi
    echo "$pattern" >> "$file"
  fi
}

# Create .claude directory if it doesn't exist
mkdir -p "$project_dir/.claude"

# Create gitignore if it doesn't exist
if [ ! -f "$gitignore_file" ]; then
  touch "$gitignore_file"
fi

# Ensure each pattern is present
for pattern in "${patterns[@]}"; do
  ensure_pattern "$pattern" "$gitignore_file"
done

exit 0
