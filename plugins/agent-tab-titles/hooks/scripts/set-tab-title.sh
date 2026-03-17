#!/usr/bin/env bash
# set-tab-title.sh — Set tmux window/pane title to agent name or role
#
# Uses CLAUDE_CODE_AGENT_NAME (teammate display name) if available,
# falls back to CLAUDE_CODE_AGENT_TYPE, then to "claude".
#
# Works in tmux -CC (iTerm2 control mode) — each tmux window maps
# to an iTerm2 tab, so rename-window sets the tab title.

set -euo pipefail

_json_msg() {
  local msg="$1"
  if command -v jq &>/dev/null; then
    jq -n --arg msg "$msg" '{additionalContext: $msg, systemMessage: $msg}'
  else
    local escaped
    escaped=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    echo "{\"additionalContext\":\"${escaped}\",\"systemMessage\":\"${escaped}\"}"
  fi
}

# Read hook input (SessionStart provides agent_type, session_id, etc.)
INPUT=$(cat 2>/dev/null || echo '')
HOOK_AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null || true)

# Priority: CLAUDE_CODE_AGENT_NAME > hook agent_type > CLAUDE_CODE_AGENT_TYPE > "claude"
TITLE="${CLAUDE_CODE_AGENT_NAME:-${HOOK_AGENT_TYPE:-${CLAUDE_CODE_AGENT_TYPE:-claude}}}"

# Skip if not in a tmux session
if [ -z "${TMUX:-}" ]; then
  # Not in tmux — use OSC 0 escape sequence for native terminal title
  printf '\033]0;%s\007' "$TITLE" >&2
  echo "agent-tab-titles: set terminal title to '$TITLE'" >&2
  _json_msg "agent-tab-titles: set terminal title to '$TITLE'"
  exit 0
fi

# Set tmux window name (shows as iTerm2 tab title in -CC mode)
tmux rename-window "$TITLE" 2>/dev/null || true

# Set tmux pane title (shows in per-pane title bar if enabled)
tmux select-pane -T "$TITLE" 2>/dev/null || true

# Disable automatic rename so the title sticks
tmux set-window-option automatic-rename off 2>/dev/null || true

echo "agent-tab-titles: set tmux title to '$TITLE'" >&2
_json_msg "agent-tab-titles: set tmux title to '$TITLE'"
