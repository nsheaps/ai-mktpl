#!/bin/bash

# Claude Code SessionStart Hook
# IMPORTANT: This hook is special - the output from this hook is added to Claude's context,
# so we need to be careful what we print to stdout. Only essential information should go to stdout.
# Everything else should go to stderr for logging purposes.
# Processes JSON input from stdin and tracks session startup, resume, and clear events.
# Usage: Called automatically by Claude Code for session start events

set -euo pipefail

# Parse JSON input from stdin and print it
INPUT=$(cat)
echo "SessionStart hook input:" >&2
echo "$INPUT" >&2

# Check if otel-cli is available
if ! command -v otel-cli >/dev/null 2>&1; then
    echo "otel-cli not available, skipping telemetry" >&2
else
    # Extract session information
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
    MATCHER=$(echo "$INPUT" | jq -r '.matcher // ""')

    # Create a single-point span for the session start event
    TIMESTAMP=$(date +%s.%N)

    # Store session start time in state file
    STATE_DIR="$HOME/.local/aiagent-claude/data"
    STATE_FILE="$STATE_DIR/state.json"
    
    # Create directory if it doesn't exist
    mkdir -p "$STATE_DIR"
    
    # Initialize or update the state file with session start time
    if [ -f "$STATE_FILE" ]; then
        # Update existing file
        jq --arg timestamp "$TIMESTAMP" '.session.startTime = $timestamp' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    else
        # Create new file
        jq -n --arg timestamp "$TIMESTAMP" '{session: {startTime: $timestamp}}' > "$STATE_FILE"
    fi
    
    echo "[STATE] Stored session start time: $TIMESTAMP" >&2

    # ref: https://github.com/equinix-labs/otel-cli
    otel-cli span \
        --name "SessionStart" \
        --service "${OTEL_SERVICE_NAME:-claude-code}" \
        --start "$TIMESTAMP" \
        --end "$TIMESTAMP" \
        --attrs "hook.type=SessionStart,session.id=$SESSION_ID,session.matcher=$MATCHER"

    echo "[TELEMETRY 👀] Tracked session start: $SESSION_ID ($MATCHER)" >&2
fi

# Extract matcher to determine the context to load
MATCHER=$(echo "$INPUT" | jq -r '.matcher // "startup"')

echo "Tracking session hook for matcher: $MATCHER" >&2

# Log matcher state for debugging (to stderr)
case "$MATCHER" in
    "startup")
        echo "[HOOK] Session Starting (startup)" >&2
        ;;
    "resume")
        echo "[HOOK] Session Resuming (resume)" >&2
        ;;
    "clear")
        echo "[HOOK] Session Cleared (clear)" >&2
        ;;
    *)
        echo "[HOOK] Session Starting (unknown matcher: $MATCHER)" >&2
        ;;
esac

# anything printed to stdout here will be shown to claude before working on the task, be careful what you print
cat <<EOF
Tracked SessionStart hook
EOF