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

SETTINGS_FILE="$HOME/.claude/settings.local.json"

# --- Source shared libs ---

PLUGIN_NAME="datadog-otel-setup"

CONFIG_LIB="${CLAUDE_PLUGIN_ROOT}/lib/plugin-config.sh"
if [ ! -f "$CONFIG_LIB" ]; then
  echo "ERROR: shared lib not found: $CONFIG_LIB" >&2
  exit 2
fi
source "$CONFIG_LIB"

SETTINGS_LIB="${CLAUDE_PLUGIN_ROOT}/lib/safe-settings-write.sh"
if [ ! -f "$SETTINGS_LIB" ]; then
  echo "ERROR: shared lib not found: $SETTINGS_LIB" >&2
  exit 2
fi
source "$SETTINGS_LIB"

# --- Check if enabled ---

if ! plugin_is_enabled; then
  echo '{}'
  exit 0
fi

# --- Read config values ---

endpoint="$(plugin_config "endpoint" "https://otel.datadoghq.com:4317")"
metrics_exporter="$(plugin_config "metrics_exporter" "otlp")"
logs_exporter="$(plugin_config "logs_exporter" "otlp")"
api_key_raw="$(plugin_config "api_key" '${DD_API_KEY}')"

# --- Resolve API key ---

api_key="$(plugin_resolve_secret "$api_key_raw" "api_key")"

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
