#!/usr/bin/env bash
# Claude Code Diagnostics - captures /status-like info and /context
# Usage: bash claude-diagnostics.sh | pbcopy

set -euo pipefail

echo "=== Claude Code Diagnostics ==="
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# Get init info and /context via stream-json (init = status-like info)
OUTPUT=$(echo '{"type":"user","message":{"role":"user","content":"/context"},"session_id":"default","parent_tool_use_id":null}' \
  | claude -p --input-format stream-json --output-format stream-json 2>&1)

# Extract init info (this is essentially /status data)
echo "## Status"
echo "$OUTPUT" | head -1 | jq -r '
"Version: \(.claude_code_version // "unknown")
Model: \(.model // "unknown")
Permission Mode: \(.permissionMode // "unknown")
API Key Source: \(.apiKeySource // "unknown")
Working Directory: \(.cwd // "unknown")

### MCP Servers
\(if (.mcp_servers // []) | length > 0 then
  (.mcp_servers | map("- \(.name): \(.status)") | join("\n"))
else
  "(none)"
end)

### Agents
\((.agents // []) | join(", ") | if . == "" then "(none)" else . end)

### Plugins
\(if (.plugins // []) | length > 0 then
  (.plugins | map("- \(.name)") | join("\n"))
else
  "(none)"
end)

### Slash Commands
\((.slash_commands // []) | join(", ") | if . == "" then "(none)" else . end)
"'

echo ""
echo "## Context"
echo "$OUTPUT" | grep '"type":"user"' | jq -r '.message.content' \
  | sed 's/<local-command-stdout>//g' | sed 's/<\/local-command-stdout>//g'

echo ""
echo "=== End Diagnostics ==="
