#!/bin/bash
# Linear Hash Save Hook (PostToolUse)
#
# This hook runs after Linear MCP read operations and saves a hash of the
# response to track the state of tickets. This enables detecting when a
# ticket has been modified externally before allowing updates.
#
# Triggered by: mcp__linear__getIssue, mcp__linear__issue (read operations)

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Extract relevant fields
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
TOOL_RESPONSE=$(echo "$INPUT" | jq -c '.tool_response // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# Skip if no response data
if [ -z "$TOOL_RESPONSE" ] || [ "$TOOL_RESPONSE" = "null" ] || [ "$TOOL_RESPONSE" = "{}" ]; then
    echo '{"decision": {"behavior": "allow"}}'
    exit 0
fi

# Extract issue identifier - Linear uses 'id' or 'identifier' fields
# Try multiple possible fields for the issue ID
ISSUE_ID=$(echo "$TOOL_RESPONSE" | jq -r '.identifier // .id // empty' 2>/dev/null)

# If we still don't have an ID, try to extract from tool input
if [ -z "$ISSUE_ID" ]; then
    ISSUE_ID=$(echo "$INPUT" | jq -r '.tool_input.issueId // .tool_input.id // .tool_input.identifier // empty')
fi

# Skip if no issue ID found
if [ -z "$ISSUE_ID" ]; then
    echo '{"decision": {"behavior": "allow"}}'
    exit 0
fi

# Create hash of the response data (normalize JSON first for consistent hashing)
ISSUE_HASH=$(echo "$TOOL_RESPONSE" | jq -cS '.' | sha256sum | awk '{print $1}')

# Determine storage location - use session-specific file in temp directory
HASH_DIR="${TMPDIR:-/tmp}/linear-mcp-hashes"
HASH_FILE="${HASH_DIR}/${SESSION_ID}.json"

mkdir -p "$HASH_DIR"

# Initialize hash file if it doesn't exist
if [ ! -f "$HASH_FILE" ]; then
    echo '{}' > "$HASH_FILE"
fi

# Update the hash file with this issue's hash
# Uses jq to merge the new entry into the existing file
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
UPDATED=$(jq --arg id "$ISSUE_ID" \
              --arg hash "$ISSUE_HASH" \
              --arg ts "$TIMESTAMP" \
              --arg tool "$TOOL_NAME" \
              '.[$id] = {"hash": $hash, "timestamp": $ts, "tool": $tool}' \
              "$HASH_FILE")

echo "$UPDATED" > "$HASH_FILE"

# Log the save operation (optional, for debugging)
# echo "[linear-hash-save] Saved hash for $ISSUE_ID: $ISSUE_HASH" >&2

# Allow the operation to continue
echo '{"decision": {"behavior": "allow"}}'
