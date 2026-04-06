#!/usr/bin/env bash
# notify.sh — Send notifications via configured channels (Telegram, etc.)
#
# Usage:
#   bash notify.sh <event_type> <message>
#
# Arguments:
#   event_type: One of: promptSave, memorySync, cronCreate, cronDelete
#   message:    Human-readable notification text
#
# Reads configuration from plugins.settings.yaml under:
#   agentic-behavior.notifications.enabled       — global toggle
#   agentic-behavior.notifications.telegram.chatId
#   agentic-behavior.notifications.telegram.botToken — typically ${TELEGRAM_BOT_TOKEN} from env
#   agentic-behavior.notifications.events.<type> — per-event toggle
#
# This script is informational only and always exits 0.

set -euo pipefail

PLUGIN_NAME="agentic-behavior"
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"

# --- Arguments ---
event_type="${1:-}"
message="${2:-}"

if [ -z "$event_type" ] || [ -z "$message" ]; then
  echo "notify.sh: usage: notify.sh <event_type> <message>" >&2
  exit 0
fi

# --- Check global notifications toggle ---
notifications_enabled="$(plugin_get_config "notifications.enabled" "false")"
if [ "$notifications_enabled" != "true" ]; then
  exit 0
fi

# --- Check per-event toggle ---
event_enabled="$(plugin_get_config "notifications.events.${event_type}" "true")"
if [ "$event_enabled" != "true" ]; then
  exit 0
fi

# --- Read Telegram config ---
chat_id="$(plugin_get_config "notifications.telegram.chatId" "")"
bot_token="$(plugin_get_config "notifications.telegram.botToken" "")"

# Expand env var references like ${TELEGRAM_BOT_TOKEN}
# If the value looks like ${VAR_NAME}, resolve it from the environment
if [[ "$bot_token" =~ ^\$\{([A-Za-z_][A-Za-z0-9_]*)\}$ ]]; then
  var_name="${BASH_REMATCH[1]}"
  bot_token="${!var_name:-}"
fi

if [ -z "$chat_id" ] || [ -z "$bot_token" ]; then
  # Telegram not configured — skip silently
  exit 0
fi

# --- Build notification text ---
session_id="${CLAUDE_SESSION_ID:-unknown}"
project_dir="${CLAUDE_PROJECT_DIR:-unknown}"
timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

text="$(jq -rn \
  --arg event "$event_type" \
  --arg msg "$message" \
  --arg ts "$timestamp" \
  --arg sid "$session_id" \
  --arg proj "$project_dir" \
  '"\(.event) | \(.msg)\nSession: \(.sid)\nProject: \(.proj)\nTime: \(.ts)"'
)"

# --- Send via Telegram Bot API ---
api_url="https://api.telegram.org/bot${bot_token}/sendMessage"

payload="$(jq -n \
  --arg chat_id "$chat_id" \
  --arg text "$text" \
  '{
    chat_id: $chat_id,
    text: $text,
    disable_notification: false
  }'
)"

# Best-effort send — never block the hook
curl -s --max-time 5 -X POST "$api_url" \
  -H "Content-Type: application/json" \
  -d "$payload" \
  >/dev/null 2>&1 || true

exit 0
