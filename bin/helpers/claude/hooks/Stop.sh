#!/bin/bash

# Claude Code SubagentStop Hook
# Processes JSON input from stdin and tracks subagent termination with otel-cli
# Usage: Called automatically by Claude Code when subagents stop

set -euo pipefail

# Parse JSON input from stdin and print it
INPUT=$(cat)
echo "Stop hook input:" >&2
echo "$INPUT" >&2

# Check if otel-cli is available
if ! command -v otel-cli >/dev/null 2>&1; then
    echo "otel-cli not available, skipping telemetry" >&2
    exit 0
fi

# Extract subagent information
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')

# Create a single-point span for the subagent stop event
TIMESTAMP=$(date +%s.%N)

# ref: https://github.com/equinix-labs/otel-cli
otel-cli span \
    --name "Stop" \
    --service "${OTEL_SERVICE_NAME:-claude-code}" \
    --start "$TIMESTAMP" \
    --end "$TIMESTAMP" \
    --attrs "hook.type=Stop,session.id=$SESSION_ID"

echo "[TELEMETRY 👀] Tracked stop: $SESSION_ID" >&2
