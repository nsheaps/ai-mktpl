#!/usr/bin/env bash
# Configure Claude Code's OTEL integration for Datadog
#
# This hook runs at session start and configures the appropriate settings.json
# file with OpenTelemetry environment variables for Datadog.
#
# Settings are loaded from:
# 1. plugins/datadog-otel-setup/datadog-otel-setup.settings.yaml (if exists)
# 2. .claude/plugins.settings.yaml -> datadog-otel-setup section
# 3. Defaults (endpoint: https://otel.datadoghq.com:4317)

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Source the shared settings library
if [[ -f "$PROJECT_DIR/.claude/lib/load-plugin-settings.sh" ]]; then
  source "$PROJECT_DIR/.claude/lib/load-plugin-settings.sh"
else
  echo "⚠️  OTEL: Settings library not found, using defaults"
  load_plugin_settings() { echo "${2:-{}}"; }
  get_setting() { echo "${3:-}"; }
  resolve_env_var() { echo "$1"; }
  resolve_target_settings_file() { echo "$PROJECT_DIR/.claude/settings.local.json"; }
fi

# Default settings - env keys match OTEL environment variable names
DEFAULT_SETTINGS='{
  "target": "local",
  "enabled": true,
  "api_key": "${DD_API_KEY}",
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_METRICS_EXPORTER": "otlp",
    "OTEL_LOGS_EXPORTER": "otlp",
    "OTEL_EXPORTER_OTLP_PROTOCOL": "grpc",
    "OTEL_EXPORTER_OTLP_ENDPOINT": "https://otel.datadoghq.com:4317",
    "OTEL_RESOURCE_ATTRIBUTES": "service.name=claude-code,deployment.environment=development"
  }
}'

# Load settings
SETTINGS=$(load_plugin_settings "datadog-otel-setup" "$DEFAULT_SETTINGS")

# Check if enabled
ENABLED=$(get_setting "$SETTINGS" ".enabled" "true")
if [[ "$ENABLED" != "true" ]]; then
  exit 0
fi

# Resolve target settings file using shared library
TARGET=$(get_setting "$SETTINGS" ".target" "local")
SETTINGS_FILE=$(resolve_target_settings_file "$TARGET" "$PROJECT_DIR")

# Resolve API key
API_KEY_RAW=$(get_setting "$SETTINGS" ".api_key" "\${DD_API_KEY}")
API_KEY=$(resolve_env_var "$API_KEY_RAW")

# Check if API key is available
if [[ -z "$API_KEY" ]]; then
  # Try 1Password if api_key looks like a reference
  if [[ "$API_KEY_RAW" == op://* ]] && command -v op >/dev/null 2>&1; then
    API_KEY=$(op read "$API_KEY_RAW" 2>/dev/null || echo "")
  fi
fi

if [[ -z "$API_KEY" ]]; then
  echo "⚠️  OTEL: No API key available (set DD_API_KEY or configure api_key)"
  exit 0
fi

# Ensure directory exists
mkdir -p "$(dirname "$SETTINGS_FILE")"

# Read existing settings or create empty object
if [[ -f "$SETTINGS_FILE" ]]; then
  EXISTING=$(cat "$SETTINGS_FILE")
else
  EXISTING="{}"
fi

# Build env object from settings, resolving env vars and adding API key header
OTEL_ENV=$(echo "$SETTINGS" | jq -r --arg api_key "$API_KEY" '
  .env // {} |
  to_entries |
  map(
    if .key == "OTEL_EXPORTER_OTLP_HEADERS" then
      .value = "DD-API-KEY=\($api_key)"
    else
      .
    end
  ) |
  from_entries |
  . + {"OTEL_EXPORTER_OTLP_HEADERS": "DD-API-KEY=\($api_key)"}
')

# Merge with existing settings
UPDATED=$(echo "$EXISTING" | jq --argjson otel "$OTEL_ENV" '
  .env = ((.env // {}) * $otel)
')

# Write back
echo "$UPDATED" | jq '.' >"$SETTINGS_FILE"

echo "✅ OTEL: Configured for Datadog in $(basename "$SETTINGS_FILE")"
