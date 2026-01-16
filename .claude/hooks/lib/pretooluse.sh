#!/usr/bin/env bash
# Shared helpers for PreToolUse hooks
# Source this file: source "$(dirname "$0")/../lib/pretooluse.sh"

# Allow the tool call
allow() {
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
  exit 0
}

# Deny the tool call with a reason
# Usage: deny "Reason for denial"
deny() {
  local reason="$1"
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":$(echo "$reason" | jq -Rs .)}}"
  exit 0
}
