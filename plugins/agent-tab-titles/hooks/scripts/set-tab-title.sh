#!/usr/bin/env bash
# set-tab-title.sh — Set tmux window/pane title to agent name or role
#
# Uses CLAUDE_CODE_AGENT_NAME (teammate display name) if available,
# falls back to CLAUDE_CODE_AGENT_TYPE, then to "claude".
#
# Works in tmux -CC (iTerm2 control mode) — each tmux window maps
# to an iTerm2 tab, so rename-window sets the tab title.

set -euo pipefail


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
      echo "[agent-tab-titles] timed out waiting for $SHARED_LIB_DIR/$lib (shared-lib SessionStart copy)" >&2
      exit 1
    fi
    sleep 0.5
  done
}

_wait_for_shared_lib "hook-output.sh"

# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/hook-output.sh"
# Read hook input (SessionStart provides agent_type, session_id, etc.)
INPUT=$(cat 2>/dev/null || echo '')
HOOK_AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null || true)

# Priority: CLAUDE_CODE_AGENT_NAME > hook agent_type > CLAUDE_CODE_AGENT_TYPE > "claude"
TITLE="${CLAUDE_CODE_AGENT_NAME:-${HOOK_AGENT_TYPE:-${CLAUDE_CODE_AGENT_TYPE:-claude}}}"

# Skip if not in a tmux session
if [ -z "${TMUX:-}" ]; then
  # Not in tmux — use OSC 0 escape sequence for native terminal title
  printf '\033]0;%s\007' "$TITLE" >&2
  hook_msg "agent-tab-titles: set terminal title to '$TITLE'"
  exit 0
fi

# Set tmux window name (shows as iTerm2 tab title in -CC mode)
tmux rename-window "$TITLE" 2>/dev/null || true

# Set tmux pane title (shows in per-pane title bar if enabled)
tmux select-pane -T "$TITLE" 2>/dev/null || true

# Disable automatic rename so the title sticks
tmux set-window-option automatic-rename off 2>/dev/null || true

hook_msg "agent-tab-titles: set tmux title to '$TITLE'"
