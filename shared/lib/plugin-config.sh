#!/usr/bin/env bash
# plugin-config.sh — Shared config resolution and secret handling for plugins
#
# Provides a three-level YAML config resolution chain (project → user → plugin
# defaults) and a secret resolver that supports env var references, 1Password
# references, and literal values.
#
# Usage:
#   PLUGIN_NAME="my-plugin"
#   source "path/to/plugin-config.sh"
#
#   value="$(plugin_config "some_key" "default_value")"
#   secret="$(plugin_resolve_secret "$value" "some_key")"
#
# Config resolution order:
#   1. Project-level: ${CLAUDE_PROJECT_DIR}/.claude/plugins.settings.yaml → .${PLUGIN_NAME}.key
#   2. User-level:    ~/.claude/plugins.settings.yaml                     → .${PLUGIN_NAME}.key
#   3. Plugin defaults: ${PLUGIN_DEFAULTS_FILE}                           → .${PLUGIN_NAME}.key
#
# PLUGIN_DEFAULTS_FILE auto-detection (first match):
#   - ${CLAUDE_PLUGIN_ROOT}/${PLUGIN_NAME}.settings.yaml
#   - ${CLAUDE_PLUGIN_ROOT}/config/${PLUGIN_NAME}.settings.yaml
#
# Requires: yq (mikefarah/yq)
# Note: Plugins copy (or symlink) this file into their own lib/ directory.
# Symlinked content is resolved and copied on plugin install.

# --- Guard: PLUGIN_NAME must be set ---

if [ -z "${PLUGIN_NAME:-}" ]; then
  echo "ERROR: plugin-config.sh: PLUGIN_NAME must be set before sourcing" >&2
  return 2 2>/dev/null || exit 2
fi

# --- Auto-detect defaults file ---

if [ -z "${PLUGIN_DEFAULTS_FILE:-}" ]; then
  if [ -f "${CLAUDE_PLUGIN_ROOT:-}/${PLUGIN_NAME}.settings.yaml" ]; then
    PLUGIN_DEFAULTS_FILE="${CLAUDE_PLUGIN_ROOT}/${PLUGIN_NAME}.settings.yaml"
  elif [ -f "${CLAUDE_PLUGIN_ROOT:-}/config/${PLUGIN_NAME}.settings.yaml" ]; then
    PLUGIN_DEFAULTS_FILE="${CLAUDE_PLUGIN_ROOT}/config/${PLUGIN_NAME}.settings.yaml"
  else
    PLUGIN_DEFAULTS_FILE=""
  fi
fi

# --- Internal: read a single key from a YAML file ---

_plugin_read_config_key() {
  local file="$1"
  local key="$2"
  if [ -f "$file" ] && command -v yq &>/dev/null; then
    local val
    val="$(yq -r ".${PLUGIN_NAME}.${key}" "$file" 2>/dev/null || true)"
    if [ -n "$val" ] && [ "$val" != "null" ]; then
      echo "$val"
      return 0
    fi
  fi
  return 1
}

# --- Public: get a config value with fallback chain ---

plugin_config() {
  local key="$1"
  local default="${2:-}"

  local val

  # 1. Project-level
  local project_config="${CLAUDE_PROJECT_DIR:-.}/.claude/plugins.settings.yaml"
  if val="$(_plugin_read_config_key "$project_config" "$key")"; then
    echo "$val"
    return
  fi

  # 2. User-level
  local user_config="$HOME/.claude/plugins.settings.yaml"
  if val="$(_plugin_read_config_key "$user_config" "$key")"; then
    echo "$val"
    return
  fi

  # 3. Plugin-level defaults
  if [ -n "${PLUGIN_DEFAULTS_FILE:-}" ]; then
    if val="$(_plugin_read_config_key "$PLUGIN_DEFAULTS_FILE" "$key")"; then
      echo "$val"
      return
    fi
  fi

  # 4. Hardcoded default
  echo "$default"
}

# --- Public: resolve a secret value ---
#
# Supports three formats:
#   ${VAR_NAME}            — expanded from shell environment
#   op://vault/item/field  — resolved via 1Password CLI
#   anything else          — used as-is (literal)
#
# Returns empty string and prints a warning on failure.

plugin_resolve_secret() {
  local raw="$1"
  local label="${2:-secret}"

  # Empty/null
  if [ -z "$raw" ] || [ "$raw" = "null" ]; then
    echo ""
    return
  fi

  # env var reference: ${VAR_NAME}
  if [[ "$raw" =~ ^\$\{([A-Za-z_][A-Za-z0-9_]*)\}$ ]]; then
    local var_name="${BASH_REMATCH[1]}"
    local resolved="${!var_name:-}"
    if [ -z "$resolved" ]; then
      echo "INFO: ${PLUGIN_NAME}: env var $var_name is not set ($label)" >&2
    fi
    echo "$resolved"
    return
  fi

  # 1Password reference: op://vault/item/field
  if [[ "$raw" == op://* ]]; then
    if ! command -v op &>/dev/null; then
      echo "WARNING: ${PLUGIN_NAME}: 1Password CLI (op) not found, cannot resolve $label" >&2
      echo ""
      return
    fi
    local resolved
    resolved="$(op read "$raw" 2>/dev/null || true)"
    if [ -z "$resolved" ]; then
      echo "WARNING: ${PLUGIN_NAME}: failed to resolve 1Password ref for $label" >&2
    fi
    echo "$resolved"
    return
  fi

  # Literal value
  echo "$raw"
}

# --- Public: check if plugin is enabled (convenience) ---

plugin_is_enabled() {
  local enabled
  enabled="$(plugin_config "enabled" "true")"
  [ "$enabled" != "false" ]
}
