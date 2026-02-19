#!/usr/bin/env bash
# Configure statusLine.command in user's settings.local.json to use this plugin's script
#
# IMPORTANT: This plugin writes to settings.local.json (NOT settings.json) to avoid
# blanking or corrupting user-managed settings. Claude Code merges settings.local.json
# on top of settings.json at runtime, so plugin-managed keys still take effect.
set -euo pipefail

# Skip configuration for agent team teammates to avoid race conditions
# on the shared settings file. Only the lead or solo sessions configure.
if [ -n "${CLAUDE_CODE_PARENT_SESSION_ID:-}" ]; then
  echo '{}'
  exit 0
fi

# Use settings.local.json to avoid overwriting user-managed settings.json
SETTINGS_FILE="$HOME/.claude/settings.local.json"
STATUSLINE_SCRIPT="${CLAUDE_PLUGIN_ROOT}/bin/statusline.sh"

# Ensure settings directory exists
mkdir -p "$(dirname "$SETTINGS_FILE")"

# Backup settings.local.json before any writes (best-effort, non-fatal)
if [ -f "$SETTINGS_FILE" ]; then
  cp "$SETTINGS_FILE" "${SETTINGS_FILE}.backup" 2>/dev/null || true
fi

# Source shared atomic settings writer (symlinked into plugin, resolved on install)
# shellcheck source=../lib/safe-settings-write.sh
SHARED_LIB="${CLAUDE_PLUGIN_ROOT}/lib/safe-settings-write.sh"
if [ ! -f "$SHARED_LIB" ]; then
  echo "ERROR: shared lib not found: $SHARED_LIB" >&2
  exit 2
fi
source "$SHARED_LIB"

# Read current statusLine.command from settings.local.json
current_command=$(jq -r '.statusLine.command // empty' "$SETTINGS_FILE" 2>/dev/null || echo "")

# Also check settings.json for an existing statusLine.command (read-only, never written)
main_settings="$HOME/.claude/settings.json"
main_command=""
if [ -f "$main_settings" ]; then
  main_command=$(jq -r '.statusLine.command // empty' "$main_settings" 2>/dev/null || echo "")
fi

# Case 1: Not present in settings.local.json - set it
if [ -z "$current_command" ]; then
  # If settings.json has a non-plugin statusLine, warn and block (don't override via local)
  if [ -n "$main_command" ] \
     && [[ "$main_command" != *"plugins/statusline-iterm"* ]] \
     && [[ "$main_command" != *"plugins/statusline/"* ]]; then
    cat <<EOF
statusLine.command is already configured in settings.json with a different script:
   Current: $main_command
   This plugin wants to use: $STATUSLINE_SCRIPT

To resolve this issue, either:
1. Ask the user which statusline script they prefer
2. Manually update ~/.claude/settings.json or ~/.claude/settings.local.json
3. Disable this plugin if they want to keep their current statusline

The statusline-iterm plugin will not override your existing configuration automatically.
EOF
    exit 2
  fi
  safe_write_settings '.statusLine.type = "command" | .statusLine.command = $script'
  exit 0
fi

# Case 2: Present and matches this plugin or the original statusline plugin - update silently
if [[ "$current_command" == *"plugins/statusline-iterm"* ]] || [[ "$current_command" == *"plugins/statusline/"* ]]; then
  safe_write_settings '.statusLine.command = $script'
  exit 0
fi

# Case 3: Present in settings.local.json and doesn't match - warn and block
cat <<EOF
statusLine.command is already configured in settings.local.json with a different script:
   Current: $current_command
   This plugin wants to use: $STATUSLINE_SCRIPT

To resolve this issue, either:
1. Ask the user which statusline script they prefer
2. Manually update ~/.claude/settings.local.json to use this plugin's script
3. Disable this plugin if they want to keep their current statusline

The statusline-iterm plugin will not override your existing configuration automatically.
EOF

exit 2
