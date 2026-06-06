#!/usr/bin/env bash
# Configure statusLine.command in user's settings.local.json to use this plugin's script
# Writes to settings.local.json (never settings.json) to prevent truncation of user config.
# Claude Code merges settings.local.json on top of settings.json at runtime.
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
      echo "[statusline] timed out waiting for $SHARED_LIB_DIR/$lib (shared-lib SessionStart copy)" >&2
      exit 1
    fi
    sleep 0.5
  done
}

_wait_for_shared_lib "hook-output.sh"

# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/hook-output.sh"
# Skip configuration for agent team teammates to avoid race conditions.
# Only the lead or solo sessions configure.
if [ -n "${CLAUDE_CODE_PARENT_SESSION_ID:-}" ]; then
  hook_msg "statusline: sub-agent session, skipping"
  exit 0
fi

# Write target: settings.local.json (merged on top of settings.json by Claude Code)
SETTINGS_FILE="$HOME/.claude/settings.local.json"
SETTINGS_BASE="$HOME/.claude/settings.json"
STATUSLINE_SCRIPT="${CLAUDE_PLUGIN_ROOT}/bin/statusline.sh"

# Ensure settings directory exists
mkdir -p "$(dirname "$SETTINGS_FILE")"

# Source shared atomic settings writer (symlinked into plugin, resolved on install)
# shellcheck source=../lib/safe-settings-write.sh
SHARED_LIB="${CLAUDE_PLUGIN_ROOT}/lib/safe-settings-write.sh"
if [ ! -f "$SHARED_LIB" ]; then
  hook_msg "statusline: ERROR — shared lib not found: $SHARED_LIB"
  exit 0
fi
source "$SHARED_LIB"

# Read effective statusLine.command: settings.local.json overrides settings.json
current_command=$(jq -r '.statusLine.command // empty' "$SETTINGS_FILE" 2>/dev/null || echo "")
if [ -z "$current_command" ]; then
  current_command=$(jq -r '.statusLine.command // empty' "$SETTINGS_BASE" 2>/dev/null || echo "")
fi

# Case 1: Not present anywhere - set it
if [ -z "$current_command" ]; then
  safe_write_settings '.statusLine.type = "command" | .statusLine.command = $script'
  hook_msg "statusline: configured"
  exit 0
fi

# Case 2: Present and matches this plugin - update silently
# Match if path contains "plugins/statusline" or points to statusline.sh
if [[ "$current_command" == *"plugins/statusline"* ]] || [[ "$current_command" == *"statusline.sh"* ]]; then
  safe_write_settings '.statusLine.command = $script'
  hook_msg "statusline: updated"
  exit 0
fi

# Case 3: Present and doesn't match - warn and block
msg="statusline: WARNING — statusLine.command is already configured with a different script:
   Current: $current_command
   This plugin wants to use: $STATUSLINE_SCRIPT

To resolve this issue, either:
1. Ask the user which statusline script they prefer
2. Manually update ~/.claude/settings.local.json to use this plugin's script
3. Disable this plugin if they want to keep their current statusline

The statusline plugin will not override your existing configuration automatically."
hook_msg "$msg"
exit 0
