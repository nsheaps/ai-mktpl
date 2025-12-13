#!/bin/bash

# Claude Code UserPromptSubmit Hook
# Processes JSON input from stdin and tracks user prompt submissions with otel-cli
# Usage: Called automatically by Claude Code for user prompt submission events

set -euo pipefail

# Parse JSON input from stdin and print it
INPUT=$(cat)
echo "UserPromptSubmit hook input:" >&2
echo "$INPUT" >&2

# Check if otel-cli is available
if ! command -v otel-cli >/dev/null 2>&1; then
    echo "otel-cli not available, skipping telemetry" >&2
    exit 0
fi

# Extract notification message
MESSAGE=$(echo "$INPUT" | jq -r '.prompt // ""')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')

# Create a single-point span for the notification
TIMESTAMP=$(date +%s.%N)

# ref: https://github.com/equinix-labs/otel-cli
otel-cli span \
    --name "UserPromptSubmit" \
    --service "${OTEL_SERVICE_NAME:-claude-code}" \
    --start "$TIMESTAMP" \
    --end "$TIMESTAMP" \
    --attrs "hook.type=UserPromptSubmit,userprompt.prompt=$MESSAGE,session.id=$SESSION_ID"

echo "[TELEMETRY 👀] Tracked user prompt submission: $MESSAGE" >&2
