#!/usr/bin/env bash
# tmux-helpers.sh - Utility functions for managing tmux sub-agent sessions
#
# Source this file or use individual commands:
#   source tmux-helpers.sh
#   subagent_list
#   subagent_status <session-name>
#   subagent_output <session-name> [lines]
#   subagent_send <session-name> <message>
#   subagent_kill <session-name>

set -euo pipefail

# List all sub-agent sessions
subagent_list() {
    echo "Active sub-agent sessions:"
    echo "=========================="
    tmux list-sessions 2>/dev/null | grep -E "^subagent-" || echo "No active sub-agent sessions"
}

# Get status of a specific session
subagent_status() {
    local session="${1:-}"
    if [[ -z "$session" ]]; then
        echo "Usage: subagent_status <session-name>"
        return 1
    fi

    if tmux has-session -t "$session" 2>/dev/null; then
        echo "Session: $session"
        echo "Status: Active"
        echo ""
        echo "Window info:"
        tmux list-windows -t "$session" 2>/dev/null
        echo ""
        echo "Pane info:"
        tmux list-panes -t "$session" 2>/dev/null
    else
        echo "Session '$session' not found"
        return 1
    fi
}

# Capture recent output from a session
# Usage: subagent_output <session> [lines] [start-line]
subagent_output() {
    local session="${1:-}"
    local lines="${2:-100}"
    local start="${3:-0}"

    if [[ -z "$session" ]]; then
        echo "Usage: subagent_output <session-name> [lines] [start-line]"
        return 1
    fi

    if ! tmux has-session -t "$session" 2>/dev/null; then
        echo "Session '$session' not found"
        return 1
    fi

    # Capture pane contents
    # -p prints to stdout, -S specifies start line (negative = from end)
    if [[ "$start" -eq 0 ]]; then
        tmux capture-pane -t "$session" -p -S "-$lines"
    else
        tmux capture-pane -t "$session" -p -S "$start" -E "$((start + lines))"
    fi
}

# Get the full scrollback history
subagent_history() {
    local session="${1:-}"

    if [[ -z "$session" ]]; then
        echo "Usage: subagent_history <session-name>"
        return 1
    fi

    if ! tmux has-session -t "$session" 2>/dev/null; then
        echo "Session '$session' not found"
        return 1
    fi

    # Capture entire history (-S - means from the start)
    tmux capture-pane -t "$session" -p -S -
}

# Send a message/command to a session
subagent_send() {
    local session="${1:-}"
    local message="${2:-}"

    if [[ -z "$session" || -z "$message" ]]; then
        echo "Usage: subagent_send <session-name> <message>"
        return 1
    fi

    if ! tmux has-session -t "$session" 2>/dev/null; then
        echo "Session '$session' not found"
        return 1
    fi

    tmux send-keys -t "$session" "$message" Enter
    echo "Sent message to $session"
}

# Send interrupt (Ctrl-C) to a session
subagent_interrupt() {
    local session="${1:-}"

    if [[ -z "$session" ]]; then
        echo "Usage: subagent_interrupt <session-name>"
        return 1
    fi

    if ! tmux has-session -t "$session" 2>/dev/null; then
        echo "Session '$session' not found"
        return 1
    fi

    tmux send-keys -t "$session" C-c
    echo "Sent interrupt to $session"
}

# Kill a sub-agent session
subagent_kill() {
    local session="${1:-}"

    if [[ -z "$session" ]]; then
        echo "Usage: subagent_kill <session-name>"
        return 1
    fi

    if ! tmux has-session -t "$session" 2>/dev/null; then
        echo "Session '$session' not found"
        return 1
    fi

    # First try to gracefully exit claude
    tmux send-keys -t "$session" "/exit" Enter
    sleep 1

    # Then kill the session
    tmux kill-session -t "$session" 2>/dev/null || true
    echo "Killed session: $session"

    # Cleanup workspace
    local workspace="/tmp/claude-subagent/${session}"
    if [[ -d "$workspace" ]]; then
        rm -rf "$workspace"
        echo "Cleaned up workspace: $workspace"
    fi
}

# Kill all sub-agent sessions
subagent_kill_all() {
    echo "Killing all sub-agent sessions..."
    for session in $(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep -E "^subagent-"); do
        subagent_kill "$session"
    done
    echo "Done"
}

# Wait for a session to complete (claude exits)
subagent_wait() {
    local session="${1:-}"
    local timeout="${2:-3600}"  # Default 1 hour timeout

    if [[ -z "$session" ]]; then
        echo "Usage: subagent_wait <session-name> [timeout-seconds]"
        return 1
    fi

    local start_time=$(date +%s)
    while tmux has-session -t "$session" 2>/dev/null; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        if [[ $elapsed -ge $timeout ]]; then
            echo "Timeout waiting for session $session"
            return 1
        fi
        sleep 5
    done
    echo "Session $session completed"
}

# Get workspace path for a session
subagent_workspace() {
    local session="${1:-}"

    if [[ -z "$session" ]]; then
        echo "Usage: subagent_workspace <session-name>"
        return 1
    fi

    local workspace="/tmp/claude-subagent/${session}"
    if [[ -d "$workspace" ]]; then
        echo "$workspace"
    else
        echo "Workspace not found for session: $session"
        return 1
    fi
}

# Export functions if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f subagent_list
    export -f subagent_status
    export -f subagent_output
    export -f subagent_history
    export -f subagent_send
    export -f subagent_interrupt
    export -f subagent_kill
    export -f subagent_kill_all
    export -f subagent_wait
    export -f subagent_workspace
fi

# If run directly with a command, execute it
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cmd="${1:-help}"
    shift || true

    case "$cmd" in
        list) subagent_list "$@" ;;
        status) subagent_status "$@" ;;
        output) subagent_output "$@" ;;
        history) subagent_history "$@" ;;
        send) subagent_send "$@" ;;
        interrupt) subagent_interrupt "$@" ;;
        kill) subagent_kill "$@" ;;
        kill-all) subagent_kill_all "$@" ;;
        wait) subagent_wait "$@" ;;
        workspace) subagent_workspace "$@" ;;
        help|*)
            echo "tmux-helpers.sh - Manage tmux sub-agent sessions"
            echo ""
            echo "Commands:"
            echo "  list                    List all sub-agent sessions"
            echo "  status <session>        Get status of a session"
            echo "  output <session> [n]    Get last n lines of output"
            echo "  history <session>       Get full scrollback history"
            echo "  send <session> <msg>    Send message to session"
            echo "  interrupt <session>     Send Ctrl-C to session"
            echo "  kill <session>          Kill a session"
            echo "  kill-all                Kill all sub-agent sessions"
            echo "  wait <session> [secs]   Wait for session to complete"
            echo "  workspace <session>     Get workspace path"
            echo ""
            ;;
    esac
fi
