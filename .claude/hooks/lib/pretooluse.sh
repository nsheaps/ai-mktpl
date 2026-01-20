#!/usr/bin/env bash
# Shared helpers for PreToolUse hooks
# Source this file: source "$(dirname "$0")/../lib/pretooluse.sh"
#
# Official docs: https://docs.anthropic.com/en/docs/claude-code/hooks
#
# Response format:
# {
#   "hookSpecificOutput": {
#     "permissionDecision": "allow" | "deny" | "ask",
#     "permissionDecisionReason": "string",      // Optional
#     "updatedInput": { ... },                   // Optional: modify tool params
#     "additionalContext": "string"              // Optional: context for Claude
#   }
# }

# Allow the tool call
# Usage: allow
# Usage: allow "Optional reason shown to user"
allow() {
  local reason="${1:-}"
  if [ -n "$reason" ]; then
    echo "{\"hookSpecificOutput\":{\"permissionDecision\":\"allow\",\"permissionDecisionReason\":$(echo "$reason" | jq -Rs .)}}"
  else
    echo '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
  fi
  exit 0
}

# Deny the tool call with a reason (shown to Claude)
# Usage: deny "Reason for denial"
deny() {
  local reason="$1"
  echo "{\"hookSpecificOutput\":{\"permissionDecision\":\"deny\",\"permissionDecisionReason\":$(echo "$reason" | jq -Rs .)}}"
  exit 0
}

# Ask user for confirmation before proceeding
# Usage: ask "Confirm this operation?"
ask() {
  local reason="${1:-Confirm this operation?}"
  echo "{\"hookSpecificOutput\":{\"permissionDecision\":\"ask\",\"permissionDecisionReason\":$(echo "$reason" | jq -Rs .)}}"
  exit 0
}

# Allow with modified input parameters
# Usage: allow_with_input '{"file_path": "/new/path"}'
allow_with_input() {
  local updated_input="$1"
  echo "{\"hookSpecificOutput\":{\"permissionDecision\":\"allow\",\"updatedInput\":$updated_input}}"
  exit 0
}

# Allow with additional context for Claude
# Usage: allow_with_context "Current environment: production"
allow_with_context() {
  local context="$1"
  echo "{\"hookSpecificOutput\":{\"permissionDecision\":\"allow\",\"additionalContext\":$(echo "$context" | jq -Rs .)}}"
  exit 0
}
