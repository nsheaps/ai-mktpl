#!/usr/bin/env bash
# PostToolUse hook: Lint files after Write tool
# Runs just lint on the file that was just written

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Only process Write tool calls
if [[ "$TOOL_NAME" != "Write" ]]; then
    exit 0
fi

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Only lint files that prettier can handle
case "$FILE_PATH" in
    *.json|*.yaml|*.yml|*.md|*.js|*.ts|*.jsx|*.tsx|*.css|*.html)
        echo "Linting: $FILE_PATH" >&2
        just lint "$FILE_PATH" 2>/dev/null || true
        ;;
esac

exit 0
