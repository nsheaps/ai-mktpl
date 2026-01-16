#!/usr/bin/env bash
# PreToolUse hook to validate git state before self-termination
# Ensures clean working directory before allowing Claude to terminate

set -euo pipefail

# Only intercept when running the self-terminate script
TOOL_NAME=$(echo "$PRETOOLUSE_TOOL" | jq -r '.tool // empty')
COMMAND=$(echo "$PRETOOLUSE_TOOL" | jq -r '.command // empty')

# Check if this is a Bash tool call running self-terminate
if [[ "$TOOL_NAME" != "Bash" ]]; then
    exit 0  # Allow - not a bash command
fi

if [[ "$COMMAND" != *"self-terminate"* ]]; then
    exit 0  # Allow - not running self-terminate
fi

# We're about to self-terminate, validate git state
cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0

# Check for uncommitted changes
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    cat <<EOF
⚠️  Cannot terminate: Uncommitted changes detected

Please commit your changes before terminating:
  git add .
  git commit -m "your message"

Or discard changes:
  git restore .
  git clean -fd
EOF
    exit 1  # Block termination
fi

# Check for unpushed commits
if git log @{u}.. --oneline 2>/dev/null | grep -q .; then
    cat <<EOF
⚠️  Cannot terminate: Unpushed commits detected

Please push your commits before terminating:
  git push

Or if you want to discard unpushed commits:
  git reset --hard @{u}
EOF
    exit 1  # Block termination
fi

# Check for untracked files (excluding common ignorable patterns)
untracked=$(git ls-files --others --exclude-standard 2>/dev/null || echo "")
if [[ -n "$untracked" ]]; then
    cat <<EOF
⚠️  Cannot terminate: Untracked files detected

Untracked files:
$untracked

Please either:
  1. Add and commit them: git add . && git commit -m "message"
  2. Add to .gitignore
  3. Remove them: git clean -fd
EOF
    exit 1  # Block termination
fi

# All checks passed - allow termination
exit 0
