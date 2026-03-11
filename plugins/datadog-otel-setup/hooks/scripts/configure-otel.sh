#!/usr/bin/env bash
# configure-otel.sh — SessionStart hook for datadog-otel-setup plugin
#
# Reads plugin config, resolves the Datadog API key, and writes OTEL
# environment variables to settings.local.json so Claude Code enables
# native OpenTelemetry export to Datadog.
#
# API key resolution:
#   - env var reference: ${DD_API_KEY} → expanded from environment
#   - 1Password ref:     op://vault/item/field → resolved via `op read`
#   - literal:           used as-is
set -euo pipefail

PLUGIN_NAME="datadog-otel-setup"
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"

SETTINGS_FILE="$HOME/.claude/settings.local.json"

# Source shared atomic settings writer
source "${CLAUDE_PLUGIN_ROOT}/lib/safe-settings-write.sh"

# --- Check if enabled ---

plugin_is_enabled || { echo '{}'; exit 0; }

# --- Read config values ---

endpoint="$(plugin_get_config "endpoint" "https://otel.datadoghq.com:4317")"
metrics_exporter="$(plugin_get_config "metricsExporter" "otlp")"
logs_exporter="$(plugin_get_config "logsExporter" "otlp")"
api_key_raw="$(plugin_get_config "apiKey" '${DD_API_KEY}')"

# --- Resolve API key ---

resolve_api_key() {
  local raw="$1"

  # env var reference: ${VAR_NAME}
  if [[ "$raw" =~ ^\$\{([A-Za-z_][A-Za-z0-9_]*)\}$ ]]; then
    local var_name="${BASH_REMATCH[1]}"
    local resolved="${!var_name:-}"
    if [ -z "$resolved" ]; then
      echo "WARNING: ${PLUGIN_NAME}: env var $var_name is not set, OTEL headers will be empty" >&2
      echo ""
      return
    fi
    echo "$resolved"
    return
  fi

  # 1Password reference: op://vault/item/field
  if [[ "$raw" == op://* ]]; then
    if ! command -v op &>/dev/null; then
      echo "WARNING: ${PLUGIN_NAME}: 1Password CLI (op) not found, cannot resolve $raw" >&2
      echo ""
      return
    fi
    local resolved
    resolved="$(op read "$raw" 2>/dev/null || true)"
    if [ -z "$resolved" ]; then
      echo "WARNING: ${PLUGIN_NAME}: failed to resolve 1Password ref $raw" >&2
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

if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

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
