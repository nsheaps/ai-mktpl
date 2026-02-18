#!/usr/bin/env bash
# Configure statusLine.command in user's settings.json to use this plugin's script
set -euo pipefail

# Skip configuration for agent team teammates to avoid race conditions
# on the shared settings.json file. Only the lead or solo sessions configure.
if [ -n "${CLAUDE_CODE_PARENT_SESSION_ID:-}" ]; then
  echo '{}'
  exit 0
fi

SETTINGS_FILE="$HOME/.claude/settings.json"
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

# Read current statusLine.command value (no lock needed for read-only)
current_command=$(jq -r '.statusLine.command // empty' "$SETTINGS_FILE" 2>/dev/null || echo "")

# Case 1: Not present - set it
if [ -z "$current_command" ]; then
  safe_write_settings '.statusLine.type = "command" | .statusLine.command = $script'
  exit 0
fi

# Case 2: Present and matches this plugin or the original statusline plugin - update silently
# Match if path contains "plugins/statusline-iterm" or "plugins/statusline/" (original plugin)
if [[ "$current_command" == *"plugins/statusline-iterm"* ]] || [[ "$current_command" == *"plugins/statusline/"* ]]; then
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
2. Manually update ~/.claude/settings.json to use this plugin's script
3. Disable this plugin if they want to keep their current statusline

The statusline-iterm plugin will not override your existing configuration automatically.
EOF

exit 2
