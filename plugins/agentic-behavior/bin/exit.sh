#!/usr/bin/env bash
# Exit script for Claude Code
# Sends SIGINT to the Claude process that spawned this shell

set -euo pipefail

LOG_PREFIX="exit"
# shellcheck source=../lib/log.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/log.sh"

# Traverse up the process tree to find Claude
find_claude_pid() {
    local pid="$PPID"
    local max_depth=10
    local depth=0

    while [[ $depth -lt $max_depth ]]; do
        local process_name
        process_name=$(ps -o comm= -p "$pid" 2>/dev/null || echo "")

        if [[ -z "$process_name" ]]; then
            log_error "Could not find Claude in process tree (reached PID $pid)"
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
            log_error "Reached init without finding Claude"
            return 1
        fi

        pid="$parent_pid"
        ((depth++))
    done

    log_error "Max depth reached without finding Claude"
    return 1
}

CLAUDE_PID=$(find_claude_pid)

if [[ -z "$CLAUDE_PID" ]]; then
    exit 1
fi

log_info "Found Claude process (PID: $CLAUDE_PID)"
log_info "Sending SIGINT..."
kill -INT "$CLAUDE_PID"
