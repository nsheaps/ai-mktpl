#!/usr/bin/env bash
# notify.sh — Send notifications via configured channels (Telegram, Discord, etc.)
#
# Usage:
#   bash notify.sh <event_type> <message>
#
# Arguments:
#   event_type: One of: promptSave, memorySync, cronCreate, cronDelete
#   message:    Human-readable notification text
#
# Reads configuration from plugins.settings.yaml under:
#   agentic-behavior.notifications.enabled            — global toggle
#   agentic-behavior.notifications.telegram.chatId
#   agentic-behavior.notifications.telegram.botToken  — typically ${TELEGRAM_BOT_TOKEN} from env
#   agentic-behavior.notifications.discord.channelId
#   agentic-behavior.notifications.discord.botToken   — typically ${DISCORD_BOT_TOKEN} from env
#   agentic-behavior.notifications.events.<type>      — per-event toggle
#
# Both channels are optional. Whichever are configured will receive the notification.
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

# --- Send via Telegram Bot API (if configured) ---
tg_chat_id="$(plugin_get_config "notifications.telegram.chatId" "")"
tg_bot_token="$(plugin_get_config "notifications.telegram.botToken" "")"

# Expand env var references like ${TELEGRAM_BOT_TOKEN}
if [[ "$tg_bot_token" =~ ^\$\{([A-Za-z_][A-Za-z0-9_]*)\}$ ]]; then
  var_name="${BASH_REMATCH[1]}"
  tg_bot_token="${!var_name:-}"
fi

if [ -n "$tg_chat_id" ] && [ -n "$tg_bot_token" ]; then
  tg_api_url="https://api.telegram.org/bot${tg_bot_token}/sendMessage"
  tg_payload="$(jq -n \
    --arg chat_id "$tg_chat_id" \
    --arg text "$text" \
    '{
      chat_id: $chat_id,
      text: $text,
      disable_notification: false
    }'
  )"
  # Best-effort send — never block the hook
  curl -s --max-time 5 -X POST "$tg_api_url" \
    -H "Content-Type: application/json" \
    -d "$tg_payload" \
    >/dev/null 2>&1 || true
fi

# --- Send via Discord Bot API (if configured) ---
dc_channel_id="$(plugin_get_config "notifications.discord.channelId" "")"
dc_bot_token="$(plugin_get_config "notifications.discord.botToken" "")"

# Expand env var references like ${DISCORD_BOT_TOKEN}
if [[ "$dc_bot_token" =~ ^\$\{([A-Za-z_][A-Za-z0-9_]*)\}$ ]]; then
  var_name="${BASH_REMATCH[1]}"
  dc_bot_token="${!var_name:-}"
fi

if [ -n "$dc_channel_id" ] && [ -n "$dc_bot_token" ]; then
  dc_api_url="https://discord.com/api/v10/channels/${dc_channel_id}/messages"
  dc_payload="$(jq -n \
    --arg content "$text" \
    '{
      content: $content
    }'
  )"
  # Best-effort send — never block the hook
  curl -s --max-time 5 -X POST "$dc_api_url" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bot ${dc_bot_token}" \
    -d "$dc_payload" \
    >/dev/null 2>&1 || true
fi

exit 0
