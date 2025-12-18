#!/bin/bash
# Linear Hash Check Hook (PreToolUse)
#
# This hook runs before Linear MCP update operations and verifies that
# the issue was previously fetched. This prevents updating stale data
# and ensures we have the latest state before making changes.
#
# Triggered by: mcp__linear__updateIssue, mcp__linear__issueUpdate (write operations)
#
# Behavior:
# - If issue was never fetched: DENY update, require fetch first
# - If issue was fetched: ALLOW update to proceed

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Extract relevant fields
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# Extract issue identifier from the update request
# Linear update tools typically use 'issueId', 'id', or 'identifier'
ISSUE_ID=$(echo "$TOOL_INPUT" | jq -r '.issueId // .id // .identifier // empty')

# If no issue ID in the request, we can't validate - allow but warn
if [ -z "$ISSUE_ID" ]; then
    echo '{"decision": {"behavior": "allow"}, "systemMessage": "Warning: Could not extract issue ID from update request for hash validation."}'
    exit 0
fi

# Determine storage location
HASH_DIR="${TMPDIR:-/tmp}/linear-mcp-hashes"
HASH_FILE="${HASH_DIR}/${SESSION_ID}.json"

# Check if hash file exists
if [ ! -f "$HASH_FILE" ]; then
    # No hash file means no issues have been fetched this session
    cat <<EOF
{
  "decision": {
    "behavior": "deny",
    "message": "Cannot update issue ${ISSUE_ID}: No issues have been fetched in this session. Please read the issue first using the Linear MCP getIssue tool before updating it. This ensures you have the latest data and prevents overwriting changes made by others."
  }
}
EOF
    exit 0
fi

# Check if this specific issue has been fetched
STORED_HASH=$(jq -r --arg id "$ISSUE_ID" '.[$id].hash // empty' "$HASH_FILE")
STORED_TIMESTAMP=$(jq -r --arg id "$ISSUE_ID" '.[$id].timestamp // empty' "$HASH_FILE")

if [ -z "$STORED_HASH" ]; then
    # Issue was never fetched in this session
    cat <<EOF
{
  "decision": {
    "behavior": "deny",
    "message": "Cannot update issue ${ISSUE_ID}: This issue has not been fetched in the current session. Please read the issue first using the Linear MCP getIssue tool before updating it. This ensures you have the latest data and prevents overwriting changes made by others."
  }
}
EOF
    exit 0
fi

# Issue was previously fetched - allow the update
# Include metadata in system message for transparency
cat <<EOF
{
  "decision": {
    "behavior": "allow"
  },
  "systemMessage": "Hash validation passed for issue ${ISSUE_ID}. Issue was last fetched at ${STORED_TIMESTAMP}."
}
EOF
