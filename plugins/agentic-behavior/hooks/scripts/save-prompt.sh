#!/usr/bin/env bash
# save-prompt.sh — Saves user prompts to ~/.claude/history.jsonl
# Runs on UserPromptSubmit hook
#
# Inspired by the Serena MCP "Ralph loop" pattern:
# - Save the original prompt so the agent can self-check against it
# - Remind the agent to validate work against what was actually asked

set -euo pipefail

PLUGIN_NAME="agentic-behavior"


# --- Source shared libs from shared-lib plugin's persistent data dir ---
#
# shared-lib (declared in plugin.json `dependencies`) copies its lib/*.sh
# files into ${CLAUDE_PLUGIN_DATA}/lib on SessionStart. We resolve its data
# dir by stripping our own data-dir name and appending shared-lib's id.
# Plugin data dir IDs are deterministic: `{plugin-name}-{marketplace-name}`.
# See https://code.claude.com/docs/en/plugins-reference#persistent-data-directory
#
# When CLAUDE_PLUGIN_DATA is unset (e.g. when this script is invoked
# outside a Claude Code hook), fall back to the known path.
if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  SHARED_LIB_DIR="${CLAUDE_PLUGIN_DATA%/*}/shared-lib-ai-mktpl/lib"
else
  SHARED_LIB_DIR="${HOME}/.claude/plugins/data/shared-lib-ai-mktpl/lib"
fi

# Wait up to ~10s for a shared-lib file to appear (handles parallel
# SessionStart hooks where shared-lib's copy may not have completed yet).
_wait_for_shared_lib() {
  local lib="$1"
  local i=0
  while [ ! -f "$SHARED_LIB_DIR/$lib" ]; do
    i=$((i + 1))
    if [ "$i" -ge 20 ]; then
      echo "[agentic-behavior] timed out waiting for $SHARED_LIB_DIR/$lib (shared-lib SessionStart copy)" >&2
      exit 1
    fi
    sleep 0.5
  done
}

_wait_for_shared_lib "hook-logging.sh"
_wait_for_shared_lib "plugin-config-read.sh"

# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/hook-logging.sh"
# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/plugin-config-read.sh"
# Check if plugin is enabled
if ! plugin_is_enabled; then
  hook_respond
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
  hook_respond
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

if [ "$self_check" = "always" ] || { [ "$self_check" = "first" ] && [ ! -f "${HOME}/.claude/.agentic-behavior-reminded-${CLAUDE_SESSION_ID:-default}" ]; }; then
  cat <<'REMINDER' >&2
<system-reminder>Prompt saved to ~/.claude/history.jsonl. Don't forget to check your work against what the user asked for to ensure you're implementing the correct thing, both while you work, and an explicit reminder to yourself about the prompt before stop.</system-reminder>
REMINDER

  # Mark that we've shown the reminder this session (for "first" mode)
  if [ "$self_check" = "first" ]; then
    touch "${HOME}/.claude/.agentic-behavior-reminded-${CLAUDE_SESSION_ID:-default}"
  fi
fi

# Return empty JSON (informational hook, no blocking)
hook_respond
