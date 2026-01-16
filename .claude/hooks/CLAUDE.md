# Hooks

## run-hook.sh

Auto-discovers and runs all executable scripts in `.claude/hooks/<hook-name>/`:

```bash
./run-hook.sh <hook-name> [args...]
```

Scripts run sequentially, each receiving Claude's stdin JSON input.

## Writing Hooks

### Internal Filtering

Scripts should filter by tool/event type internally rather than relying on matchers in settings.json. This allows a single `run-hook.sh` entry to handle all cases.

```bash
#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Filter internally - approve tools we don't handle
if [[ "$TOOL_NAME" != "Bash" ]]; then
    echo '{"status": "approved"}'
    exit 0
fi

# Your logic here...
```

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
