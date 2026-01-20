#!/usr/bin/env bash
# Load settings for a plugin from YAML or JSON files
#
# Usage:
#   source load-plugin-settings.sh
#   settings=$(load_plugin_settings "plugin-name" '{"default": "value"}')
#
# Resolution order (first found wins):
# 1. plugins/<plugin-name>/<plugin-name>.settings.yaml
# 2. plugins/<plugin-name>/<plugin-name>.settings.yml
# 3. plugins/<plugin-name>/<plugin-name>.settings.json
# 4. .claude/plugins.settings.yaml → <plugin-name>: section
# 5. .claude/plugins.settings.yml → <plugin-name>: section
# 6. .claude/plugins.settings.json → <plugin-name> key
# 7. Default settings (if provided)

set -euo pipefail

# Check if yq is available for YAML parsing
_has_yq() {
  command -v yq >/dev/null 2>&1
}

# Convert YAML file to JSON
_yaml_to_json() {
  local file="$1"
  if _has_yq; then
    yq -o=json '.' "$file" 2>/dev/null
  else
    echo "ERROR: yq is required for YAML parsing but not installed" >&2
    return 1
  fi
}

# Extract plugin section from a settings file (YAML or JSON)
_extract_plugin_section() {
  local file="$1"
  local plugin_name="$2"
  local extension="${file##*.}"

  case "$extension" in
    yaml|yml)
      if _has_yq; then
        yq -o=json ".[\"$plugin_name\"] // null" "$file" 2>/dev/null
      else
        echo "null"
      fi
      ;;
    json)
      jq ".[\"$plugin_name\"] // null" "$file" 2>/dev/null
      ;;
    *)
      echo "null"
      ;;
  esac
}

# Load settings for a plugin
# Arguments:
#   $1 - plugin name (required)
#   $2 - default settings as JSON (optional, defaults to {})
# Output:
#   JSON object with settings
load_plugin_settings() {
  local plugin_name="$1"
  local defaults="${2:-{}}"
  local settings=""
  local project_dir="${CLAUDE_PROJECT_DIR:-.}"

  # Check plugin-specific files first
  for ext in yaml yml json; do
    local plugin_file="$project_dir/plugins/$plugin_name/$plugin_name.settings.$ext"
    if [[ -f "$plugin_file" ]]; then
      case "$ext" in
        yaml|yml)
          settings=$(_yaml_to_json "$plugin_file")
          ;;
        json)
          settings=$(cat "$plugin_file")
          ;;
      esac
      if [[ -n "$settings" && "$settings" != "null" ]]; then
        echo "$settings"
        return 0
      fi
    fi
  done

  # Fall back to central settings file
  for ext in yaml yml json; do
    local central_file="$project_dir/.claude/plugins.settings.$ext"
    if [[ -f "$central_file" ]]; then
      settings=$(_extract_plugin_section "$central_file" "$plugin_name")
      if [[ -n "$settings" && "$settings" != "null" ]]; then
        echo "$settings"
        return 0
      fi
    fi
  done

  # Fall back to defaults
  echo "$defaults"
}

# Get a specific setting value
# Arguments:
#   $1 - settings JSON
#   $2 - key path (jq syntax, e.g., ".endpoint" or ".nested.key")
#   $3 - default value (optional)
get_setting() {
  local settings="$1"
  local key="$2"
  local default="${3:-}"

  local value
  value=$(echo "$settings" | jq -r "$key // empty" 2>/dev/null)

  if [[ -z "$value" ]]; then
    echo "$default"
  else
    echo "$value"
  fi
}

# Resolve environment variable references in a value using envsubst
# Supports: ${VAR_NAME} and ${VAR_NAME:-default} syntax
resolve_env_var() {
  local value="$1"

  # Use envsubst for robust variable expansion
  if command -v envsubst >/dev/null 2>&1; then
    echo "$value" | envsubst
  else
    # Fallback: simple regex for ${VAR_NAME} only
    if [[ "$value" =~ ^\$\{([A-Za-z_][A-Za-z0-9_]*)\}$ ]]; then
      local var_name="${BASH_REMATCH[1]}"
      echo "${!var_name:-}"
    else
      echo "$value"
    fi
  fi
}

# Resolve target name to settings file path
# Arguments:
#   $1 - target name (local|project|user)
#   $2 - project directory (optional, defaults to CLAUDE_PROJECT_DIR or .)
# Output:
#   Absolute path to the settings file
resolve_target_settings_file() {
  local target="$1"
  local project_dir="${2:-${CLAUDE_PROJECT_DIR:-.}}"

  case "$target" in
    local)
      echo "$project_dir/.claude/settings.local.json"
      ;;
    project)
      echo "$project_dir/.claude/settings.json"
      ;;
    user)
      echo "${HOME}/.claude/settings.json"
      ;;
    *)
      echo "⚠️  Unknown target '$target', using local" >&2
      echo "$project_dir/.claude/settings.local.json"
      ;;
  esac
}
