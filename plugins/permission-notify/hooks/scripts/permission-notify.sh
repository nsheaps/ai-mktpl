#!/usr/bin/env bash
# permission-notify.sh — PermissionRequest hook for permission-notify plugin
#
# Sends a Telegram notification when Claude requests permission to use a tool.
# Purely informational — does NOT set a permissionDecision.
#
# Configuration (via environment):
#   TELEGRAM_BOT_TOKEN    — required; Telegram Bot API token
#   TELEGRAM_CHAT_ID      — optional; defaults to handler's chat ID (1650664303)
#
# Hook input (stdin, JSON):
#   tool_name   — e.g. Edit, Write, Bash, Read
#   tool_input  — tool-specific fields (file_path, command, old_string, etc.)
set -euo pipefail

# --- Configuration ---

CHAT_ID="${TELEGRAM_CHAT_ID:-1650664303}"
MAX_SUMMARY_LEN=200
MAX_DIFF_LEN=400

# --- Guards ---

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
  # No token configured — skip silently
  exit 0
fi

# --- Read hook input ---

INPUT=$(cat)

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")

# --- Build notification content based on tool type ---

build_notification() {
  local title detail summary

  case "$TOOL_NAME" in
    Edit)
      local file_path old_str new_str
      file_path=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
      old_str=$(printf '%s' "$INPUT" | jq -r '.tool_input.old_string // ""' 2>/dev/null)
      new_str=$(printf '%s' "$INPUT" | jq -r '.tool_input.new_string // ""' 2>/dev/null)

      title="Edit"
      detail="$file_path"

      if [[ -n "$old_str" || -n "$new_str" ]]; then
        local old_preview new_preview
        old_preview=$(printf '%s' "$old_str" | head -c "$MAX_DIFF_LEN")
        new_preview=$(printf '%s' "$new_str" | head -c "$MAX_DIFF_LEN")
        summary="- ${old_preview:-(empty)}"$'\n'"+ ${new_preview:-(empty)}"
      else
        summary="(no diff available)"
      fi
      ;;

    Write)
      local file_path content
      file_path=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
      content=$(printf '%s' "$INPUT" | jq -r '.tool_input.content // ""' 2>/dev/null)

      title="Write"
      detail="$file_path"
      summary=$(printf '%s' "$content" | head -c "$MAX_SUMMARY_LEN")
      ;;

    Bash)
      local cmd
      cmd=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

      title="Bash"
      detail=""
      summary=$(printf '%s' "$cmd" | head -c "$MAX_SUMMARY_LEN")
      ;;

    Read)
      local file_path
      file_path=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

      title="Read"
      detail="$file_path"
      summary=""
      ;;

    *)
      title="$TOOL_NAME"
      detail=$(printf '%s' "$INPUT" | jq -r '.tool_input | to_entries | map("\(.key): \(.value)") | join(", ")' 2>/dev/null | head -c "$MAX_SUMMARY_LEN" || echo "")
      summary=""
      ;;
  esac

  printf '%s\t%s\t%s' "$title" "$detail" "$summary"
}

# --- Escape HTML for Telegram ---

html_escape() {
  printf '%s' "$1" \
    | sed 's/&/\&amp;/g' \
    | sed 's/</\&lt;/g' \
    | sed 's/>/\&gt;/g'
}

# --- Main ---

NOTIFICATION=$(build_notification)
TITLE=$(printf '%s' "$NOTIFICATION" | cut -f1)
DETAIL=$(printf '%s' "$NOTIFICATION" | cut -f2)
SUMMARY=$(printf '%s' "$NOTIFICATION" | cut -f3-)

# Build HTML message
MSG="<b>🔒 Permission Request: $(html_escape "$TITLE")</b>"

if [[ -n "$DETAIL" ]]; then
  MSG+=$'\n'"📁 <code>$(html_escape "$DETAIL")</code>"
fi

if [[ -n "$SUMMARY" ]]; then
  MSG+=$'\n'"📝 <pre>$(html_escape "$SUMMARY")</pre>"
fi

# Send notification in the background — never block permission decision
(
  curl -s -X POST \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
      --arg chat_id "$CHAT_ID" \
      --arg text "$MSG" \
      '{chat_id: $chat_id, text: $text, parse_mode: "HTML"}')" \
    > /dev/null
) &
disown

# Do NOT output a permissionDecision — purely informational
exit 0
