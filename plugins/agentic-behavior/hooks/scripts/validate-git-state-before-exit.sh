#!/usr/bin/env bash
# PreToolUse hook to validate git state before session exit
# Ensures clean working directory before allowing Claude to exit

set -euo pipefail

# --- Read hook input from stdin (Claude Code PreToolUse convention) ---
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Only intercept Bash tool calls
if [[ "$TOOL_NAME" != "Bash" ]]; then
    exit 0  # Allow - not a bash command
fi

# Only intercept exit invocations (script path or kill -INT against parent)
if [[ "$COMMAND" != *"bin/exit.sh"* && "$COMMAND" != *"kill -INT"* ]]; then
    exit 0  # Allow - not running exit
fi

# We're about to exit, validate git state
cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0

# Check for uncommitted changes
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    cat <<EOF
Cannot exit: Uncommitted changes detected

Please commit your changes before exiting:
  git add .
  git commit -m "your message"

Or discard changes:
  git restore .
  git clean -fd
EOF
    exit 2  # Block exit
fi

# Check for unpushed commits
if git log @{u}.. --oneline 2>/dev/null | grep -q .; then
    cat <<EOF
Cannot exit: Unpushed commits detected

Please push your commits before exiting:
  git push

Or if you want to discard unpushed commits:
  git reset --hard @{u}
EOF
    exit 2  # Block exit
fi

# Check for untracked files (excluding common ignorable patterns)
untracked=$(git ls-files --others --exclude-standard 2>/dev/null || echo "")
if [[ -n "$untracked" ]]; then
    cat <<EOF
Cannot exit: Untracked files detected

Untracked files:
$untracked

Please either:
  1. Add and commit them: git add . && git commit -m "message"
  2. Add to .gitignore
  3. Remove them: git clean -fd
EOF
    exit 2  # Block exit
fi

# All checks passed - allow exit
exit 0
