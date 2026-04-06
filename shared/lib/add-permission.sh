#!/usr/bin/env bash
# add-permission.sh — Shared library for adding permissions to Claude Code settings
#
# Provides helpers for plugins that need to auto-configure permission scopes
# on session start. Supports writing to settings.local.json (default) or
# settings.json (shared/committed) based on the target parameter.
#
# Usage:
#   source "path/to/safe-settings-write.sh"  # Must be sourced first
#   source "path/to/add-permission.sh"
#
#   add_permission_to_allow "mcp__my-server__*"
#   add_permission_to_allow "Bash(mytool:*)" "user"  # target: "project" or "user"
#
# Requires: safe-settings-write.sh must be sourced first, jq must be available.
# Note: Plugins symlink this file into their own lib/ directory.
# Symlinked content is resolved and copied on plugin install.

# Guard against double-sourcing
if [ "${_ADD_PERMISSION_LOADED:-}" = "true" ]; then
  return 0 2>/dev/null || true
fi
_ADD_PERMISSION_LOADED="true"

# Resolve the settings file path.
# Args: $1=target, one of:
#   "project" (default) — project-level settings.local.json
#   "user"              — user-level settings.local.json
#   "local"             — same as "project" (settings.local.json, gitignored)
#   "shared"            — project-level settings.json (committed, shared with team)
# Returns: file path via stdout
_resolve_settings_file() {
  local target="${1:-project}"
  case "$target" in
    user)
      echo "$HOME/.claude/settings.local.json"
      ;;
    shared)
      if [ -z "${CLAUDE_PROJECT_DIR:-}" ]; then
        echo "add-permission: CLAUDE_PROJECT_DIR is not set; cannot resolve 'shared' target" >&2
        return 1
      fi
      echo "${CLAUDE_PROJECT_DIR}/.claude/settings.json"
      ;;
    project|local)
      if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
        echo "${CLAUDE_PROJECT_DIR}/.claude/settings.local.json"
      else
        echo "$HOME/.claude/settings.local.json"
      fi
      ;;
    *)
      echo "add-permission: unknown target '$target' (expected: project, local, user, shared)" >&2
      return 1
      ;;
  esac
}

# Add a permission entry to the "allow" list in the resolved settings file.
# Idempotent — skips if already present.
# Args: $1=permission_entry $2=target ("project", "user", "local", or "shared"; default "project")
# Returns: 0 on success or already present
add_permission_to_allow() {
  local perm="$1"
  local target="${2:-project}"
  local caller="${PLUGIN_NAME:-unknown}"

  if ! command -v jq &>/dev/null; then
    echo "${caller}: jq required but not found, skipping permission setup" >&2
    return 0
  fi

  SETTINGS_FILE="$(_resolve_settings_file "$target")"
  mkdir -p "$(dirname "$SETTINGS_FILE")"

  # Check if already present
  if [ -f "$SETTINGS_FILE" ]; then
    local existing
    existing="$(jq -r '.permissions.allow // [] | .[]' "$SETTINGS_FILE" 2>/dev/null || true)"
    if echo "$existing" | grep -qF "$perm"; then
      echo "${caller}: permission '$perm' already configured" >&2
      return 0
    fi
  fi

  export _ADD_PERM_ENTRY="$perm"
  safe_write_settings '
    .permissions.allow = (
      (.permissions.allow // []) + [$ENV._ADD_PERM_ENTRY]
      | unique
    )
  '
  unset _ADD_PERM_ENTRY

  echo "${caller}: added '$perm' to permissions.allow in $SETTINGS_FILE" >&2
}
