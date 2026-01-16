#!/usr/bin/env bash
# Self-terminate script for Claude Code
# Sends SIGINT to the Claude process that spawned this shell

set -euo pipefail

# Traverse up the process tree to find Claude
find_claude_pid() {
    local pid="$PPID"
    local max_depth=10
    local depth=0

    while [[ $depth -lt $max_depth ]]; do
        local process_name
        process_name=$(ps -o comm= -p "$pid" 2>/dev/null || echo "")

        if [[ -z "$process_name" ]]; then
            echo "Error: Could not find Claude in process tree (reached PID $pid)" >&2
            return 1
        fi

        if [[ "$process_name" == *"claude"* ]]; then
            echo "$pid"
            return 0
        fi

        # Get parent of current pid
        local parent_pid
        parent_pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')

        if [[ -z "$parent_pid" || "$parent_pid" == "0" || "$parent_pid" == "1" ]]; then
            echo "Error: Reached init without finding Claude" >&2
            return 1
        fi

        pid="$parent_pid"
        ((depth++))
    done

    echo "Error: Max depth reached without finding Claude" >&2
    return 1
}

CLAUDE_PID=$(find_claude_pid)

if [[ -z "$CLAUDE_PID" ]]; then
    exit 1
fi

echo "Found Claude process (PID: $CLAUDE_PID)"
echo "Sending SIGINT..."
kill -INT "$CLAUDE_PID"
