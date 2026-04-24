#!/usr/bin/env bash
# active-task-guard.sh — Advisory warning when a tool is used with no active task
# Triggered by PreToolUse hook (advisory only — does not block)
#
# This is a new hook with no predecessor in the consolidated plugins.
# Exit code 0 = allow (advisory warnings do not block)

set -euo pipefail

# Read hook input from stdin
input=$(cat)

# Extract the tool name from the hook input
# Hook input format: {"tool_name": "...", "tool_input": {...}, ...}
tool_name=""
if command -v jq &>/dev/null; then
  tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
fi

# Conversational tools that don't require an active task
EXEMPT_TOOLS=(
  "TodoRead"
  "TodoWrite"
  "TaskList"
  "TaskGet"
)

# Check if the tool is exempt
for exempt in "${EXEMPT_TOOLS[@]}"; do
  if [ "$tool_name" = "$exempt" ]; then
    exit 0
  fi
done

# Stub: active task detection would query TaskList here.
# For now this hook exits 0 (pass-through) — full implementation in v1.1
# when TaskList output can be reliably parsed from within a hook.

exit 0
