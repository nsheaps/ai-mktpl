#!/usr/bin/env bash
# notify-cron.sh — Send notification when CronCreate or CronDelete is used
# Runs as PostToolUse hook for CronCreate and CronDelete tools
#
# Reads the tool name from stdin hook input and sends a notification.
# Always exits 0 (informational only).

set -euo pipefail

PLUGIN_NAME="agentic-behavior"

# shellcheck source=../../lib/hook-logging.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/hook-logging.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"

# Check if plugin is enabled
if ! plugin_is_enabled; then
  hook_respond
  exit 0
fi

# Read hook input from stdin
input="$(cat)"

# Extract tool name from the hook input
tool_name="$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)"

if [ -z "$tool_name" ]; then
  hook_respond
  exit 0
fi

# Map tool name to event type and message
case "$tool_name" in
  CronCreate)
    event_type="cronCreate"
    cron_schedule="$(echo "$input" | jq -r '.tool_input.schedule // .tool_input.cron // "unknown"' 2>/dev/null || true)"
    cron_prompt="$(echo "$input" | jq -r '.tool_input.prompt // "unknown"' 2>/dev/null || true)"
    # Truncate prompt for notification
    if [ "${#cron_prompt}" -gt 80 ]; then
      cron_prompt="${cron_prompt:0:80}..."
    fi
    message="Cron created: ${cron_schedule} - ${cron_prompt}"
    ;;
  CronDelete)
    event_type="cronDelete"
    cron_id="$(echo "$input" | jq -r '.tool_input.id // .tool_input.name // "unknown"' 2>/dev/null || true)"
    message="Cron deleted: ${cron_id}"
    ;;
  *)
    # Not a cron tool — skip
    hook_respond
    exit 0
    ;;
esac

# Send notification (best-effort)
bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/notify.sh" "$event_type" "$message" || true

hook_respond
