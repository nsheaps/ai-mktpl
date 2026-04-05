#!/usr/bin/env bash
# save-prompt.sh — Saves user prompts to ~/.claude/history.jsonl
# Runs on UserPromptSubmit hook
#
# Inspired by the Serena MCP "Ralph loop" pattern:
# - Save the original prompt so the agent can self-check against it
# - Remind the agent to validate work against what was actually asked

set -euo pipefail

PLUGIN_NAME="brain"
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"

# Check if plugin is enabled
if ! plugin_is_enabled; then
  echo '{}'
  exit 0
fi

HISTORY_FILE="${HOME}/.claude/history.jsonl"

# Read hook input from stdin
input="$(cat)"

# Extract the prompt text from the hook input
prompt="$(echo "$input" | jq -r '.prompt // empty' 2>/dev/null || true)"

if [ -z "$prompt" ]; then
  # If no prompt field, try the message content
  prompt="$(echo "$input" | jq -r '.message.content // empty' 2>/dev/null || true)"
fi

# Skip saving if no extractable prompt
if [ -z "$prompt" ]; then
  echo '{}'
  exit 0
fi

# Ensure history directory exists
mkdir -p "$(dirname "$HISTORY_FILE")"

# Build the history entry
timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
session_id="${CLAUDE_SESSION_ID:-unknown}"
project_dir="${CLAUDE_PROJECT_DIR:-unknown}"

entry="$(jq -n \
  --arg ts "$timestamp" \
  --arg sid "$session_id" \
  --arg proj "$project_dir" \
  --arg prompt "$prompt" \
  '{
    timestamp: $ts,
    sessionId: $sid,
    projectDir: $proj,
    prompt: $prompt
  }'
)"

# Append to history file
echo "$entry" >> "$HISTORY_FILE"

# Output the system reminder to stderr (shown to the agent)
# This implements the "Ralph loop" self-check pattern:
# Remind the agent about the original prompt so it can validate its work
# Configurable via selfCheckReminder: "always" (default), "first", or "none"
self_check="$(plugin_get_config "selfCheckReminder" "always")"

if [ "$self_check" = "always" ] || { [ "$self_check" = "first" ] && [ ! -f "${HOME}/.claude/.brain-reminded-${CLAUDE_SESSION_ID:-default}" ]; }; then
  cat <<'REMINDER' >&2
<system-reminder>Prompt saved to ~/.claude/history.jsonl. Don't forget to check your work against what the user asked for to ensure you're implementing the correct thing, both while you work, and an explicit reminder to yourself about the prompt before stop.</system-reminder>
REMINDER

  # Mark that we've shown the reminder this session (for "first" mode)
  if [ "$self_check" = "first" ]; then
    touch "${HOME}/.claude/.brain-reminded-${CLAUDE_SESSION_ID:-default}"
  fi
fi

# Return empty JSON (informational hook, no blocking)
echo '{}'
