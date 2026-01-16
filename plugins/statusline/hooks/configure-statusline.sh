#!/usr/bin/env bash
# Configure statusLine.command in user's settings.json to use this plugin's script
set -euo pipefail

SETTINGS_FILE="$HOME/.claude/settings.json"
STATUSLINE_SCRIPT="${CLAUDE_PLUGIN_ROOT}/bin/statusline.sh"

# Ensure settings file exists
if [ ! -f "$SETTINGS_FILE" ]; then
  echo "{}" > "$SETTINGS_FILE"
fi

# Read current statusLine.command value
current_command=$(jq -r '.statusLine.command // empty' "$SETTINGS_FILE" 2>/dev/null || echo "")

# Case 1: Not present - set it
if [ -z "$current_command" ]; then
  jq --arg script "$STATUSLINE_SCRIPT" \
    '.statusLine.type = "command" | .statusLine.command = $script' \
    "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
  mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
  exit 0
fi

# Case 2: Present and matches this plugin - update silently
# Match if path contains "plugins/statusline" or points to statusline.sh
if [[ "$current_command" == *"plugins/statusline"* ]] || [[ "$current_command" == *"statusline.sh"* ]]; then
  # Update to current resolved path
  jq --arg script "$STATUSLINE_SCRIPT" \
    '.statusLine.command = $script' \
    "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
  mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
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

The statusline plugin will not override your existing configuration automatically.
EOF

exit 2
