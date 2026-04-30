#!/usr/bin/env bash
# hook-output.sh — Shared output helper for hooks that return JSON messages
#
# Provides the common pattern of outputting {additionalContext, systemMessage}
# JSON to stdout (for Claude Code to display) while also logging to stderr.
#
# Usage:
#   source "${CLAUDE_PLUGIN_ROOT}/lib/hook-output.sh"
#
#   hook_msg "statusline: configured"        # JSON to stdout + stderr
#   hook_msg_only "quiet message"            # JSON to stdout only
#
# This replaces the duplicated _json_msg() pattern found across many plugins.
# For hooks that use the full hook-logging.sh lifecycle (hook_run/hook_respond),
# use hook-logging.sh instead — this library is for simpler hooks.

# Guard against double-sourcing
if [ "${_HOOK_OUTPUT_LOADED:-}" = "true" ]; then
  return 0 2>/dev/null || true
fi
_HOOK_OUTPUT_LOADED="true"

# Output a JSON message to stdout and also log to stderr.
# Args: $1=message
hook_msg() {
  local msg="$1"
  echo "$msg" >&2
  _hook_output_json "$msg"
}

# Output a JSON message to stdout only (no stderr logging).
# Args: $1=message
hook_msg_only() {
  _hook_output_json "$1"
}

# Internal: format and output JSON to stdout.
# Uses jq if available, falls back to manual escaping.
# Args: $1=message
_hook_output_json() {
  local msg="$1"
  if command -v jq &>/dev/null; then
    jq -n --arg msg "$msg" '{additionalContext: $msg, systemMessage: $msg}'
  else
    local escaped
    escaped=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    echo "{\"additionalContext\":\"${escaped}\",\"systemMessage\":\"${escaped}\"}"
  fi
}
