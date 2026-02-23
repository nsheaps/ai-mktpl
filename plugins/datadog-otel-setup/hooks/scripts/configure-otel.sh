#!/usr/bin/env bash
# configure-otel.sh — SessionStart hook for datadog-otel-setup plugin
#
# Reads plugin config, resolves the Datadog API key, and writes OTEL
# environment variables to settings.local.json so Claude Code enables
# native OpenTelemetry export to Datadog.
#
# Config resolution order:
#   1. Project-level: ${CLAUDE_PROJECT_DIR}/.claude/plugins.settings.yaml → datadog-otel-setup
#   2. User-level:    ~/.claude/plugins.settings.yaml → datadog-otel-setup
#   3. Plugin-level:  ${CLAUDE_PLUGIN_ROOT}/datadog-otel-setup.settings.yaml → datadog-otel-setup
#
# API key resolution:
#   - env var reference: ${DD_API_KEY} → expanded from environment
#   - 1Password ref:     op://vault/item/field → resolved via `op read`
#   - literal:           used as-is
set -euo pipefail

SETTINGS_FILE="$HOME/.claude/settings.local.json"

# Source shared atomic settings writer
SHARED_LIB="${CLAUDE_PLUGIN_ROOT}/lib/safe-settings-write.sh"
if [ ! -f "$SHARED_LIB" ]; then
  echo "ERROR: shared lib not found: $SHARED_LIB" >&2
  exit 2
fi
source "$SHARED_LIB"

# --- Config resolution ---

read_config_key() {
  local file="$1"
  local key="$2"
  if [ -f "$file" ] && command -v yq &>/dev/null; then
    local val
    val="$(yq -r ".datadog-otel-setup.${key}" "$file" 2>/dev/null || true)"
    if [ -n "$val" ] && [ "$val" != "null" ]; then
      echo "$val"
      return 0
    fi
  fi
  return 1
}

get_config() {
  local key="$1"
  local default="$2"

  # 1. Project-level
  local project_config="${CLAUDE_PROJECT_DIR:-.}/.claude/plugins.settings.yaml"
  local val
  if val="$(read_config_key "$project_config" "$key")"; then
    echo "$val"
    return
  fi

  # 2. User-level
  local user_config="$HOME/.claude/plugins.settings.yaml"
  if val="$(read_config_key "$user_config" "$key")"; then
    echo "$val"
    return
  fi

  # 3. Plugin-level defaults
  local plugin_config="${CLAUDE_PLUGIN_ROOT}/datadog-otel-setup.settings.yaml"
  if val="$(read_config_key "$plugin_config" "$key")"; then
    echo "$val"
    return
  fi

  # 4. Hardcoded default
  echo "$default"
}

# --- Check if enabled ---

enabled="$(get_config "enabled" "true")"
if [ "$enabled" = "false" ]; then
  echo '{}'
  exit 0
fi

# --- Read config values ---

endpoint="$(get_config "endpoint" "https://otel.datadoghq.com:4317")"
metrics_exporter="$(get_config "metrics_exporter" "otlp")"
logs_exporter="$(get_config "logs_exporter" "otlp")"
api_key_raw="$(get_config "api_key" '${DD_API_KEY}')"

# --- Resolve API key ---

resolve_api_key() {
  local raw="$1"

  # env var reference: ${VAR_NAME}
  if [[ "$raw" =~ ^\$\{([A-Za-z_][A-Za-z0-9_]*)\}$ ]]; then
    local var_name="${BASH_REMATCH[1]}"
    local resolved="${!var_name:-}"
    if [ -z "$resolved" ]; then
      echo "WARNING: datadog-otel-setup: env var $var_name is not set, OTEL headers will be empty" >&2
      echo ""
      return
    fi
    echo "$resolved"
    return
  fi

  # 1Password reference: op://vault/item/field
  if [[ "$raw" == op://* ]]; then
    if ! command -v op &>/dev/null; then
      echo "WARNING: datadog-otel-setup: 1Password CLI (op) not found, cannot resolve $raw" >&2
      echo ""
      return
    fi
    local resolved
    resolved="$(op read "$raw" 2>/dev/null || true)"
    if [ -z "$resolved" ]; then
      echo "WARNING: datadog-otel-setup: failed to resolve 1Password ref $raw" >&2
      echo ""
      return
    fi
    echo "$resolved"
    return
  fi

  # Literal value
  echo "$raw"
}

api_key="$(resolve_api_key "$api_key_raw")"

# --- Build OTEL headers ---

otel_headers=""
if [ -n "$api_key" ]; then
  otel_headers="DD-API-KEY=${api_key}"
fi

# --- Write to settings.local.json ---

mkdir -p "$(dirname "$SETTINGS_FILE")"

# Ensure file exists
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

# Export values so jq can access them via $ENV
export OTEL_PLUGIN_METRICS_EXP="$metrics_exporter"
export OTEL_PLUGIN_LOGS_EXP="$logs_exporter"
export OTEL_PLUGIN_ENDPOINT="$endpoint"
export OTEL_PLUGIN_HEADERS="$otel_headers"

safe_write_settings \
  '.env.CLAUDE_CODE_ENABLE_TELEMETRY = "1"
   | .env.OTEL_METRICS_EXPORTER = $ENV.OTEL_PLUGIN_METRICS_EXP
   | .env.OTEL_LOGS_EXPORTER = $ENV.OTEL_PLUGIN_LOGS_EXP
   | .env.OTEL_EXPORTER_OTLP_ENDPOINT = $ENV.OTEL_PLUGIN_ENDPOINT
   | .env.OTEL_EXPORTER_OTLP_HEADERS = $ENV.OTEL_PLUGIN_HEADERS'

echo '{}'
