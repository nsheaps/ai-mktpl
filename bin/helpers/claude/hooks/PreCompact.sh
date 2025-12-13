#!/bin/bash

# Claude Code PreCompact Hook
# Processes JSON input from stdin and tracks context compaction with otel-cli
# Usage: Called automatically by Claude Code before context compaction

set -euo pipefail

# Parse JSON input from stdin and print it
INPUT=$(cat)
echo "PreCompact hook input:" >&2
echo "$INPUT" >&2

# Check if otel-cli is available
if ! command -v otel-cli >/dev/null 2>&1; then
    echo "otel-cli not available, skipping telemetry" >&2
    exit 0
fi

# Extract context size information
CONTEXT_SIZE=$(echo "$INPUT" | jq -r '.context_size // ""')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')

# Create a single-point span for the precompact event
TIMESTAMP=$(date +%s.%N)

# ref: https://github.com/equinix-labs/otel-cli
otel-cli span \
    --name "precompact" \
    --service "${OTEL_SERVICE_NAME:-claude-code}" \
    --start "$TIMESTAMP" \
    --end "$TIMESTAMP" \
    --attrs "hook.type=precompact,context.size=$CONTEXT_SIZE,session.id=$SESSION_ID"

echo "[TELEMETRY 👀] Tracked precompact event: context size $CONTEXT_SIZE" >&2
