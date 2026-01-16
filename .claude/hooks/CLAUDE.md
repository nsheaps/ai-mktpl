# Hooks

## run-hook.sh

Auto-discovers and runs all executable scripts in `.claude/hooks/<hook-name>/`:

```bash
./run-hook.sh <hook-name> [args...]
```

Scripts run sequentially, each receiving Claude's stdin JSON input.

## Writing Hooks

### Shared Library

PreToolUse hooks can source `lib/pretooluse.sh` for common helpers:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../lib/pretooluse.sh"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Filter internally - allow tools we don't handle
if [[ "$TOOL_NAME" != "Bash" ]]; then
    allow
fi

# Your logic here...
deny "Reason for blocking"
```

**Available helpers:**

- `allow` - Output allow JSON and exit
- `deny "reason"` - Output deny JSON with reason and exit

### Return Values

PreToolUse hooks must return JSON to stdout with exit code 0:

**Allow the tool call:**

```json
{ "hookSpecificOutput": { "hookEventName": "PreToolUse", "permissionDecision": "allow" } }
```

**Block the tool call:**

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "..."
  }
}
```

Use the `claude-code-guide` agent for current hook API documentation.

### Requirements

1. Must be executable (`chmod +x`)
2. Must read JSON from stdin
3. Must output valid JSON response
4. Must exit 0 (non-zero may cause issues)
5. Filter internally by tool_name/event type
