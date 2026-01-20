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

- `allow` - Allow the tool call (optional reason shown to user)
- `allow "reason"` - Allow with reason shown to user
- `deny "reason"` - Block the tool call (reason shown to Claude)
- `ask "prompt"` - Ask user for confirmation before proceeding

### Return Values

PreToolUse hooks must return JSON to stdout with exit code 0.

**Response format:**

```json
{
  "hookSpecificOutput": {
    "permissionDecision": "allow" | "deny" | "ask",
    "permissionDecisionReason": "string",
    "updatedInput": { },
    "additionalContext": "string"
  }
}
```

**Allow the tool call:**

```json
{ "hookSpecificOutput": { "permissionDecision": "allow" } }
```

**Block the tool call (reason shown to Claude):**

```json
{
  "hookSpecificOutput": {
    "permissionDecision": "deny",
    "permissionDecisionReason": "Cannot write to system directories"
  }
}
```

**Ask user for confirmation:**

```json
{
  "hookSpecificOutput": {
    "permissionDecision": "ask",
    "permissionDecisionReason": "Confirm this sensitive operation?"
  }
}
```

**Allow with modified input:**

```json
{
  "hookSpecificOutput": {
    "permissionDecision": "allow",
    "updatedInput": { "file_path": "/safe/alternative/path" }
  }
}
```

See [official docs](https://docs.anthropic.com/en/docs/claude-code/hooks) for complete API reference.

### Requirements

1. Must be executable (`chmod +x`)
2. Must read JSON from stdin
3. Must output valid JSON response
4. Must exit 0 (non-zero may cause issues)
5. Filter internally by tool_name/event type
