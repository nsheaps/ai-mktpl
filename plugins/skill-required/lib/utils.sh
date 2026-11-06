#!/usr/bin/env bash
# utils.sh — Shared utilities for skill-required plugin hooks
#
# Usage:
#   source "${CLAUDE_PLUGIN_ROOT}/lib/utils.sh"
#
#   slug="$(get_project_slug)"
#   safe_name="$(sanitize_skill_name "scm-utils:commit")"

# Guard against double-sourcing
if [ "${_SKILL_REQUIRED_UTILS_LOADED:-}" = "true" ]; then
  return 0 2>/dev/null || true
fi
_SKILL_REQUIRED_UTILS_LOADED="true"

# Generate a filesystem-safe project slug from CLAUDE_PROJECT_DIR.
# Replaces path separators with underscores and strips any leading underscore.
# Returns: slug string via stdout
get_project_slug() {
  local project_dir="${CLAUDE_PROJECT_DIR:-unknown}"
  echo "$project_dir" | sed 's|/|_|g' | sed 's|^_||'
}

# Sanitize a skill name for use as a filesystem path component.
# Replaces colons (invalid on some filesystems) with double-hyphens.
# Example: "scm-utils:commit" → "scm-utils--commit"
# Args: $1=skill_name
# Returns: sanitized name via stdout
sanitize_skill_name() {
  local name="$1"
  echo "$name" | sed 's|:|--|g'
}
