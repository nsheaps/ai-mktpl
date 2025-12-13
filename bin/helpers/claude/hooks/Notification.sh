#!/bin/bash

# Claude Code Notification Hook
# Processes JSON input from stdin and tracks notifications with otel-cli
# Usage: Called automatically by Claude Code for notification events

set -euo pipefail

# Parse JSON input from stdin and print it
INPUT=$(cat)
echo "Notification hook input:" >&2
echo "$INPUT" >&2

# Check if otel-cli is available
if ! command -v otel-cli >/dev/null 2>&1; then
    echo "otel-cli not available, skipping telemetry" >&2
    exit 0
fi

# Extract notification message
MESSAGE=$(echo "$INPUT" | jq -r '.message // ""')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')

# Create a single-point span for the notification
TIMESTAMP=$(date +%s.%N)

# ref: https://github.com/equinix-labs/otel-cli
otel-cli span \
    --name "Notification" \
    --service "${OTEL_SERVICE_NAME:-claude-code}" \
    --start "$TIMESTAMP" \
    --end "$TIMESTAMP" \
    --attrs "hook.type=Notification,notification.message=$MESSAGE,session.id=$SESSION_ID"

echo "[TELEMETRY 👀] Tracked notification: $MESSAGE" >&2
