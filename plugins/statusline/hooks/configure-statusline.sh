#!/usr/bin/env bash
# Configure statusLine.command in user's settings.local.json to use this plugin's script
# Writes to settings.local.json (never settings.json) to prevent truncation of user config.
# Claude Code merges settings.local.json on top of settings.json at runtime.
set -euo pipefail

# Skip configuration for agent team teammates to avoid race conditions.
# Only the lead or solo sessions configure.
if [ -n "${CLAUDE_CODE_PARENT_SESSION_ID:-}" ]; then
  echo '{}'
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
  echo "ERROR: shared lib not found: $SHARED_LIB" >&2
  exit 2
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
  exit 0
fi

# Case 2: Present and matches this plugin - update silently
# Match if path contains "plugins/statusline" or points to statusline.sh
if [[ "$current_command" == *"plugins/statusline"* ]] || [[ "$current_command" == *"statusline.sh"* ]]; then
  safe_write_settings '.statusLine.command = $script'
  exit 0
fi

# Case 3: Present and doesn't match - warn and block
cat <<EOF
⚠️  statusLine.command is already configured with a different script:
   Current: $current_command
   This plugin wants to use: $STATUSLINE_SCRIPT

To resolve this issue, either:
1. Ask the user which statusline script they prefer
2. Manually update ~/.claude/settings.local.json to use this plugin's script
3. Disable this plugin if they want to keep their current statusline

The statusline plugin will not override your existing configuration automatically.
EOF

exit 2
