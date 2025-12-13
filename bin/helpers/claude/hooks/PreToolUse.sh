#!/bin/bash

# Claude Code PreToolUse Hook
# Processes JSON input from stdin and tracks tool usage with otel-cli
# Usage: Called automatically by Claude Code before tool execution

set -euo pipefail

### PreToolUse looks like
# {
#   "session_id": "df6b3953-ca48-4185-8023-f3bbe93b3d52",
#   "transcript_path": "/Users/nheaps/.claude/projects/-Users-nheaps-src-gather-town-v2/df6b3953-ca48-4185-8023-f3bbe93b3d52.jsonl",
#   "cwd": "/Users/nheaps/src/gather-town-v2",
#   "hook_event_name": "PreToolUse",
#   "tool_name": "WebSearch",
#   "tool_input": {
#     "query": "breaking news today July 22 2025 past 6 hours"
#   }
# }

# Parse JSON input from stdin
INPUT=$(cat)

# Extract key fields for consistent hashing
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // "unknown"')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')

# Create consistent SHA based on session_id+cwd+tool_name+tool_input
HASH_DATA="${SESSION_ID}${CWD}${TOOL_NAME}${TOOL_INPUT}"
SOCKET_NAME=$(echo "$HASH_DATA" | sha256sum | cut -d' ' -f1 | cut -c1-10)

# Check if otel-cli is available
if ! command -v otel-cli >/dev/null 2>&1; then
    echo "otel-cli not available, skipping telemetry" >&2
    exit 0
fi

SOCKET_DIR="/tmp/otel-sockets/$SOCKET_NAME"

# Ensure socket directory exists
mkdir -p "$SOCKET_DIR"

# clear any existing socket files
rm -fv "$SOCKET_DIR"/*

TOOL_NAME_EXTRAS=""
TOOL_NAME_EXTRA_ATTRIBUTES=""

function set_attribute() {
    local key="$1"
    local value="$2"
    if [[ -n "$value" ]]; then
        TOOL_NAME_EXTRA_ATTRIBUTES="$TOOL_NAME_EXTRA_ATTRIBUTES,$key=$value"
    fi
}
# For certain tools, we want to add extra attributes that indicates
# more detail about the action being performed. Since each tool
# has it's own format for input, we need to handle them separately.
case "$TOOL_NAME" in
    "Bash")
        # for bash we want to store the command in the tool name
        # but keep the full command and description as an attribute
        # Tool input looks like:
        # {
        #   "command": "find . -type d -empty -not -path './.git/*' -not -path './node_modules/*' | while read dir; do if ! git ls-files --error-unmatch \"$dir\" >/dev/null 2>&1; then echo \"$dir\"; fi; done",
        #   "description": "Find empty directories that are not tracked by git"
        # }
        TOOL_NAME_EXTRAS="tool.command=$(echo "$TOOL_INPUT" | jq -r '.command // ""')"
        set_attribute "tool.description" "$(echo "$TOOL_INPUT" | jq -r '.description // ""')"
        set_attribute "tool.command" "$(echo "$TOOL_INPUT" | jq -c '.command // ""')"
        ;;
    "WebSearch")
        # For WebSearch, we want to add the query as an attribute
        TOOL_NAME_EXTRA_ATTRIBUTES="\"tool.query=$(echo "$TOOL_INPUT" | jq -r '.query // ""' | sed 's/"//g')\""
        ;;
    "TodoWrite")
        # For TodoWrite, we want to add an attribute with the count of EACH state of the todos
        # Tool input looks like:
        # {
        #   "todos": [
        #     {
        #       "content": "Find all empty directories in the repository",
        #       "status": "completed",
        #       "priority": "high",
        #       "id": "1"
        #     },
        #     {
        #       "content": "Filter out directories that are tracked by git",
        #       "status": "in_progress",
        #       "priority": "high",
        #       "id": "2"
        #     },
        #     {
        #       "content": "Delete the empty untracked directories",
        #       "status": "pending",
        #       "priority": "high",
        #       "id": "3"
        #     }
        #   ]
        # }
        # Do it manually here since we're mapping the json to a string
        # TOOL_NAME_EXTRA_ATTRIBUTES="$TOOL_NAME_EXTRA_ATTRIBUTES,$(
        #     echo "$TOOL_INPUT" | jq -r '
        #         .todos | group_by(.status) | map("\(. | length)") | join(",")'
        # )"
        ;;
    # For all others, we just use the tool name
    *)
        echo "No extra attributes for tool: $TOOL_NAME" >&2
        ;;
esac

# Start background span tracking
# ref: https://github.com/equinix-labs/otel-cli
if [[ -n "$TOOL_NAME_EXTRAS" ]]; then
    TOOL_NAME="$TOOL_NAME ($TOOL_NAME_EXTRAS)"
fi
ATTRS="tool.name=$TOOL_NAME,session.id=$SESSION_ID,cwd=$CWD,user=${USER:-$MCP_USER:-unknown}"
if [[ -n "$TOOL_NAME_EXTRA_ATTRIBUTES" ]]; then
    ATTRS="$ATTRS,$TOOL_NAME_EXTRA_ATTRIBUTES"
fi


# Print parsed data and shasum
echo "=== PARSED DATA ===" >&2
echo "Session ID: $SESSION_ID" >&2
echo "Tool Name: $TOOL_NAME" >&2
echo "Tool Input: $TOOL_INPUT" >&2
echo "=== SHASUM ===" >&2
echo "Hash SHA256 (10-char): $SOCKET_NAME" >&2
echo "=================" >&2

# TODO: THIS CANNOT HANDLE MULTILINE DATA
# see if we can write to a json file and just tell otel-cli
# to read it
SPAN_DATA="$SOCKET_DIR/data.env"

echo "TOOL_NAME=\"$TOOL_NAME\"" >> "$SPAN_DATA"
echo "START_TIME=$(date +%s.%N)" >> "$SPAN_DATA"
echo "ATTRS=\"$(echo $ATTRS | sed 's/\"/\\\"/g')\"" >> "$SPAN_DATA"
echo "[TELEMETRY 👀] Started tracking telemetry span data for tool: $TOOL_NAME" >&2
cat "$SPAN_DATA" >&2

