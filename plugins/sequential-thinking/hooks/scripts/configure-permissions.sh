#!/usr/bin/env bash
# configure-permissions.sh — SessionStart hook for sequential-thinking plugin
#
# Adds "mcp__sequential-thinking__*" to the allow list in settings.local.json
# so all sequential-thinking MCP tools are auto-approved without prompts.
#
# Uses the safe-settings-write shared library for atomic, concurrent-safe updates.
set -euo pipefail

# --- Check for jq ---

if ! command -v jq &>/dev/null; then
  echo "sequential-thinking: jq required but not found, skipping permission setup" >&2
  echo '{}'
  exit 0
fi

# --- Determine target settings file ---
# Write to project-level settings.local.json if CLAUDE_PROJECT_DIR is set,
# otherwise fall back to user-level.

if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  SETTINGS_FILE="${CLAUDE_PROJECT_DIR}/.claude/settings.local.json"
else
  SETTINGS_FILE="$HOME/.claude/settings.local.json"
fi

# --- Source shared lib ---

SHARED_LIB="${CLAUDE_PLUGIN_ROOT}/lib/safe-settings-write.sh"
if [ ! -f "$SHARED_LIB" ]; then
  echo "sequential-thinking: shared lib not found at $SHARED_LIB" >&2
  echo '{}'
  exit 0
fi
source "$SHARED_LIB"

# --- Ensure permissions include sequential-thinking MCP tools ---

mkdir -p "$(dirname "$SETTINGS_FILE")"

PERM_ENTRY="mcp__sequential-thinking__*"

# Check if already present to avoid duplicate work
if [ -f "$SETTINGS_FILE" ]; then
  existing="$(jq -r '.permissions.allow // [] | .[]' "$SETTINGS_FILE" 2>/dev/null || true)"
  if echo "$existing" | grep -qF "$PERM_ENTRY"; then
    echo "sequential-thinking: permissions already configured" >&2
    echo '{}'
    exit 0
  fi
fi

# Add the wildcard permission for all sequential-thinking MCP tools
safe_write_settings '
  .permissions.allow = (
    (.permissions.allow // []) + ["mcp__sequential-thinking__*"]
    | unique
  )
'

echo "sequential-thinking: added $PERM_ENTRY to permissions.allow" >&2
echo '{}'
