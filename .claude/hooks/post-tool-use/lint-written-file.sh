#!/usr/bin/env bash
# PostToolUse hook: Lint files after Write tool
# Runs mise run lint on the file that was just written

set -euo pipefail

# Source shared logging library
LOG_PREFIX="lint-hook"
# shellcheck source=../../../shared/lib/log.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../shared/lib/log.sh"

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
        log_info "Linting: $FILE_PATH"
        mise run lint "$FILE_PATH" 2>/dev/null || true
        ;;
esac

exit 0
