#!/usr/bin/env bash
# Self-terminate script for Claude Code
# Sends SIGINT to the Claude process that spawned this shell

set -euo pipefail

# Get the parent PID (Claude process)
CLAUDE_PID="$PPID"

# Verify it's actually a claude process
PROCESS_NAME=$(ps -o comm= -p "$CLAUDE_PID" 2>/dev/null || echo "unknown")

if [[ "$PROCESS_NAME" != *"claude"* ]]; then
    echo "Error: Parent process ($CLAUDE_PID) is not Claude (found: $PROCESS_NAME)" >&2
    exit 1
fi

echo "Sending SIGINT to Claude process (PID: $CLAUDE_PID)..."
kill -INT "$CLAUDE_PID"
