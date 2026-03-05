#!/usr/bin/env bash
# plugin-config-read.sh — Shared library for reading plugin settings from YAML or JSON
#
# Provides a standard 3-tier config resolution pattern for plugin hooks:
#   1. Project-level: ${CLAUDE_PROJECT_DIR}/.claude/plugins.settings.{yaml,json}
#   2. User-level:    ~/.claude/plugins.settings.{yaml,json}
#   3. Plugin-level:  ${CLAUDE_PLUGIN_ROOT}/<plugin-name>.settings.{yaml,json}
#
# At each tier, YAML is checked first, then JSON. First match wins.
#
# Usage:
#   PLUGIN_NAME="my-plugin"  # Required: set before sourcing
#   source "path/to/plugin-config-read.sh"
#   value="$(plugin_get_config "some_key" "default_value")"
#   array_values="$(plugin_get_config_array "sources")"
#
# Requires: PLUGIN_NAME must be set before sourcing.
# Optional: CLAUDE_PLUGIN_ROOT, CLAUDE_PROJECT_DIR (falls back to "." and $HOME)
# Note: Plugins symlink this file into their own lib/ directory.
# Symlinked content is resolved and copied on plugin install.

# Guard against double-sourcing
if [ "${_PLUGIN_CONFIG_READ_LOADED:-}" = "true" ]; then
  return 0 2>/dev/null || true
fi
_PLUGIN_CONFIG_READ_LOADED="true"

# Validate PLUGIN_NAME is set
if [ -z "${PLUGIN_NAME:-}" ]; then
  echo "ERROR: PLUGIN_NAME must be set before sourcing plugin-config-read.sh" >&2
  return 1 2>/dev/null || exit 1
fi

# Detect file format and read a single key from a settings file.
# Supports both YAML (via yq) and JSON (via jq).
# Args: $1=file_path $2=key_name
# Returns: value via stdout, exit 0 on success, exit 1 if not found
_plugin_read_config_key() {
  local file="$1" key="$2"
  if [ ! -f "$file" ]; then
    return 1
  fi

  local val=""
  case "$file" in
    *.json)
      if command -v jq &>/dev/null; then
        val="$(jq -r ".[\"${PLUGIN_NAME}\"].${key} // empty" "$file" 2>/dev/null || true)"
      fi
      ;;
    *.yaml|*.yml)
      if command -v yq &>/dev/null; then
        val="$(yq -r ".[\"${PLUGIN_NAME}\"].${key}" "$file" 2>/dev/null || true)"
        [ "$val" = "null" ] && val=""
      else
        # Fallback: grep for simple key: value (single-level only)
        val="$(grep -A1 "${PLUGIN_NAME}:" "$file" 2>/dev/null \
          | grep -E "^\s+${key}:" \
          | sed "s/.*${key}:\s*//" \
          | sed 's/^["'\'']//' \
          | sed 's/["'\'']$//' \
          | head -1 || true)"
      fi
      ;;
  esac

  if [ -n "$val" ]; then
    echo "$val"
    return 0
  fi
  return 1
}

# Detect file format and read an array key from a settings file.
# Supports both YAML (via yq) and JSON (via jq).
# Args: $1=file_path $2=key_name
# Returns: one value per line via stdout, exit 0 on success, exit 1 if not found
_plugin_read_config_array() {
  local file="$1" key="$2"
  if [ ! -f "$file" ]; then
    return 1
  fi

  local val=""
  case "$file" in
    *.json)
      if command -v jq &>/dev/null; then
        val="$(jq -r ".[\"${PLUGIN_NAME}\"].${key}[]? // empty" "$file" 2>/dev/null || true)"
      fi
      ;;
    *.yaml|*.yml)
      if command -v yq &>/dev/null; then
        val="$(yq -r ".[\"${PLUGIN_NAME}\"].${key}[]?" "$file" 2>/dev/null || true)"
        [ "$val" = "null" ] && val=""
      fi
      ;;
  esac

  if [ -n "$val" ]; then
    echo "$val"
    return 0
  fi
  return 1
}

# Try reading a config key from a base path, checking YAML then JSON extensions.
# Args: $1=base_path (without extension) $2=key_name
# Returns: value via stdout, exit 0 on success, exit 1 if not found
_plugin_try_config_key() {
  local base="$1" key="$2"
  local val
  if val="$(_plugin_read_config_key "${base}.yaml" "$key")"; then
    echo "$val"; return 0
  fi
  if val="$(_plugin_read_config_key "${base}.yml" "$key")"; then
    echo "$val"; return 0
  fi
  if val="$(_plugin_read_config_key "${base}.json" "$key")"; then
    echo "$val"; return 0
  fi
  return 1
}

# Try reading a config array from a base path, checking YAML then JSON extensions.
# Args: $1=base_path (without extension) $2=key_name
# Returns: one value per line via stdout, exit 0 on success, exit 1 if not found
_plugin_try_config_array() {
  local base="$1" key="$2"
  local val
  if val="$(_plugin_read_config_array "${base}.yaml" "$key")"; then
    echo "$val"; return 0
  fi
  if val="$(_plugin_read_config_array "${base}.yml" "$key")"; then
    echo "$val"; return 0
  fi
  if val="$(_plugin_read_config_array "${base}.json" "$key")"; then
    echo "$val"; return 0
  fi
  return 1
}

# Get a config value with 3-tier resolution.
# Args: $1=key_name $2=default_value
# Returns: resolved value via stdout
plugin_get_config() {
  local key="$1" default="$2"
  local val

  # 1. Project-level
  if val="$(_plugin_try_config_key "${CLAUDE_PROJECT_DIR:-.}/.claude/plugins.settings" "$key")"; then
    echo "$val"; return
  fi
  # 2. User-level
  if val="$(_plugin_try_config_key "$HOME/.claude/plugins.settings" "$key")"; then
    echo "$val"; return
  fi
  # 3. Plugin-level defaults
  if val="$(_plugin_try_config_key "${CLAUDE_PLUGIN_ROOT:-.}/${PLUGIN_NAME}.settings" "$key")"; then
    echo "$val"; return
  fi
  echo "$default"
}

# Get an array config value with 3-tier resolution.
# Args: $1=key_name
# Returns: one value per line via stdout (empty if not found)
plugin_get_config_array() {
  local key="$1"
  local val

  if val="$(_plugin_try_config_array "${CLAUDE_PROJECT_DIR:-.}/.claude/plugins.settings" "$key")"; then
    echo "$val"; return
  fi
  if val="$(_plugin_try_config_array "$HOME/.claude/plugins.settings" "$key")"; then
    echo "$val"; return
  fi
  if val="$(_plugin_try_config_array "${CLAUDE_PLUGIN_ROOT:-.}/${PLUGIN_NAME}.settings" "$key")"; then
    echo "$val"; return
  fi
}

# Check if the plugin is enabled (convenience wrapper).
# Returns: 0 if enabled, 1 if disabled
plugin_is_enabled() {
  local enabled
  enabled="$(plugin_get_config "enabled" "true")"
  [ "$enabled" != "false" ]
}
