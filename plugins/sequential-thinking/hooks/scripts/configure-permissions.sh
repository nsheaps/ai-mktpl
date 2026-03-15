#!/usr/bin/env bash
# configure-permissions.sh — SessionStart hook for sequential-thinking plugin
#
# Adds "mcp__sequential-thinking__*" to the allow list so all sequential-thinking
# MCP tools are auto-approved without prompts.
#
# Config keys (via plugins.settings.yaml):
#   syncSettingsTarget — "local" or "shared": which settings file to write to
#
# Uses the shared add-permission library for idempotent, atomic updates.
set -euo pipefail

PLUGIN_NAME="sequential-thinking"

# Source config reader for syncSettingsTarget
# shellcheck source=../../lib/plugin-config-read.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"

# Source settings writer + permission helper
# shellcheck source=../../lib/safe-settings-write.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/safe-settings-write.sh"
# shellcheck source=../../lib/add-permission.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/add-permission.sh"

SYNC_SETTINGS_TARGET="$(plugin_get_config "syncSettingsTarget" "local")"

add_permission_to_allow "mcp__sequential-thinking__*" "$SYNC_SETTINGS_TARGET"

echo '{}'
