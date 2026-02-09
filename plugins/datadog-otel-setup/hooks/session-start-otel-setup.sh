#!/usr/bin/env bash
# Configure environment variables from plugin settings
#
# Uses the plugin settings framework to read target and env vars,
# then writes them to the appropriate Claude Code settings file.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Source settings library
source "$PROJECT_DIR/.claude/lib/load-plugin-settings.sh"

# Load this plugin's settings
SETTINGS=$(load_plugin_settings "datadog-otel-setup")
TARGET=$(get_target "$SETTINGS")
ENV_VARS=$(get_env "$SETTINGS")

# Skip if no env vars configured
if [[ "$ENV_VARS" == "{}" ]]; then
  exit 0
fi

# Resolve target file
SETTINGS_FILE=$(resolve_target_file "$TARGET" "$PROJECT_DIR")

# Ensure directory exists
mkdir -p "$(dirname "$SETTINGS_FILE")"

# Read or create existing settings
if [[ -f "$SETTINGS_FILE" ]]; then
  EXISTING=$(cat "$SETTINGS_FILE")
else
  EXISTING="{}"
fi

# Merge env vars into settings
UPDATED=$(echo "$EXISTING" | jq --argjson env "$ENV_VARS" '.env = ((.env // {}) * $env)')

# Write back
echo "$UPDATED" | jq '.' > "$SETTINGS_FILE"

echo "Configured environment in $(basename "$SETTINGS_FILE")"
