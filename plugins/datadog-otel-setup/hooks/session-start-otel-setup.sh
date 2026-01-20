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

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Source the shared settings library
if [[ -f "$PROJECT_DIR/.claude/lib/load-plugin-settings.sh" ]]; then
  source "$PROJECT_DIR/.claude/lib/load-plugin-settings.sh"
else
  echo "⚠️  OTEL: Settings library not found, using defaults"
  load_plugin_settings() { echo "${2:-{}}"; }
  get_setting() { echo "${3:-}"; }
  resolve_env_var() { echo "$1"; }
fi

# Default settings
DEFAULT_SETTINGS='{
  "target": "local",
  "enabled": true,
  "endpoint": "https://otel.datadoghq.com:4317",
  "protocol": "grpc",
  "api_key": "${DD_API_KEY}",
  "resource_attributes": {
    "service.name": "claude-code",
    "deployment.environment": "development"
  }
}'

# Load settings
SETTINGS=$(load_plugin_settings "datadog-otel-setup" "$DEFAULT_SETTINGS")

# Check if enabled
ENABLED=$(get_setting "$SETTINGS" ".enabled" "true")
if [[ "$ENABLED" != "true" ]]; then
  exit 0
fi

# Resolve target settings file
TARGET=$(get_setting "$SETTINGS" ".target" "local")
case "$TARGET" in
  local)
    SETTINGS_FILE="$PROJECT_DIR/.claude/settings.local.json"
    ;;
  project)
    SETTINGS_FILE="$PROJECT_DIR/.claude/settings.json"
    ;;
  user)
    SETTINGS_FILE="${HOME}/.claude/settings.json"
    ;;
  *)
    echo "⚠️  OTEL: Unknown target '$TARGET', using local" >&2
    SETTINGS_FILE="$PROJECT_DIR/.claude/settings.local.json"
    ;;
esac

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

# Get other settings
ENDPOINT=$(get_setting "$SETTINGS" ".endpoint" "https://otel.datadoghq.com:4317")
PROTOCOL=$(get_setting "$SETTINGS" ".protocol" "grpc")

# Map protocol to OTEL format
case "$PROTOCOL" in
  grpc)
    OTEL_PROTOCOL="grpc"
    ;;
  http/json|http-json)
    OTEL_PROTOCOL="http/json"
    ;;
  http/protobuf|http-protobuf)
    OTEL_PROTOCOL="http/protobuf"
    ;;
  *)
    OTEL_PROTOCOL="grpc"
    ;;
esac

# Build resource attributes string
RESOURCE_ATTRS=""
if echo "$SETTINGS" | jq -e '.resource_attributes' >/dev/null 2>&1; then
  RESOURCE_ATTRS=$(echo "$SETTINGS" | jq -r '.resource_attributes | to_entries | map("\(.key)=\(.value)") | join(",")')
fi

# Ensure directory exists
mkdir -p "$(dirname "$SETTINGS_FILE")"

# Read existing settings or create empty object
if [[ -f "$SETTINGS_FILE" ]]; then
  EXISTING=$(cat "$SETTINGS_FILE")
else
  EXISTING="{}"
fi

# Build env object with OTEL settings
OTEL_ENV=$(jq -n \
  --arg telemetry "1" \
  --arg metrics "otlp" \
  --arg logs "otlp" \
  --arg protocol "$OTEL_PROTOCOL" \
  --arg endpoint "$ENDPOINT" \
  --arg headers "DD-API-KEY=$API_KEY" \
  --arg resource "$RESOURCE_ATTRS" \
  '{
    "CLAUDE_CODE_ENABLE_TELEMETRY": $telemetry,
    "OTEL_METRICS_EXPORTER": $metrics,
    "OTEL_LOGS_EXPORTER": $logs,
    "OTEL_EXPORTER_OTLP_PROTOCOL": $protocol,
    "OTEL_EXPORTER_OTLP_ENDPOINT": $endpoint,
    "OTEL_EXPORTER_OTLP_HEADERS": $headers
  } + (if $resource != "" then {"OTEL_RESOURCE_ATTRIBUTES": $resource} else {} end)'
)

# Merge with existing settings
UPDATED=$(echo "$EXISTING" | jq --argjson otel "$OTEL_ENV" '
  .env = ((.env // {}) * $otel)
')

# Write back
echo "$UPDATED" | jq '.' >"$SETTINGS_FILE"

echo "✅ OTEL: Configured for Datadog in $(basename "$SETTINGS_FILE")"
