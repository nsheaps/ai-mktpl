#!/usr/bin/env bash
# Minimal plugin settings library
#
# Usage:
#   source load-plugin-settings.sh
#   settings=$(load_plugin_settings "plugin-name")
#   target=$(get_target "$settings")
#   env_json=$(get_env "$settings")

set -euo pipefail

# Load settings for a plugin from central settings file
# Arguments: $1 - plugin name
# Output: JSON object with settings (or empty object)
load_plugin_settings() {
  local plugin_name="$1"
  local project_dir="${CLAUDE_PROJECT_DIR:-.}"
  local settings_file="$project_dir/.claude/plugins.settings.json"

  if [[ -f "$settings_file" ]]; then
    jq -r ".\"$plugin_name\" // {}" "$settings_file" 2>/dev/null || echo "{}"
  else
    echo "{}"
  fi
}

# Get target from settings (defaults to "local")
get_target() {
  local settings="$1"
  echo "$settings" | jq -r '.target // "local"'
}

# Get env object from settings (defaults to empty object)
get_env() {
  local settings="$1"
  echo "$settings" | jq -r '.env // {}'
}

# Resolve target name to file path
# Arguments: $1 - target name, $2 - project directory (optional)
resolve_target_file() {
  local target="$1"
  local project_dir="${2:-${CLAUDE_PROJECT_DIR:-.}}"

  case "$target" in
    local)   echo "$project_dir/.claude/settings.local.json" ;;
    project) echo "$project_dir/.claude/settings.json" ;;
    user)    echo "$HOME/.claude/settings.json" ;;
    *)       echo "$project_dir/.claude/settings.local.json" ;;
  esac
}
