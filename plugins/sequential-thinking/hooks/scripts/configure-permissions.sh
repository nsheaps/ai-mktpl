#!/usr/bin/env bash
# configure-permissions.sh — SessionStart hook for sequential-thinking plugin
#
# Adds "mcp__sequential-thinking__*" to the allow list in settings.local.json
# so all sequential-thinking MCP tools are auto-approved without prompts.
#
# Uses the shared add-permission library for idempotent, atomic updates.
set -euo pipefail

PLUGIN_NAME="sequential-thinking"
SETTINGS_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/settings.local.json"

source "${CLAUDE_PLUGIN_ROOT}/lib/safe-settings-write.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/add-permission.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/hook-logging.sh"

hook_log_step "add-permission" "Adding sequential-thinking MCP permissions"

if ! add_permission_to_allow "mcp__sequential-thinking__*"; then
  hook_fail "permission setup" "Failed to add mcp__sequential-thinking__* to allow list in $SETTINGS_FILE" \
    "Check file permissions on $SETTINGS_FILE, or verify jq is available"
  exit 0
fi

hook_log "permissions configured"
hook_log_cleanup
