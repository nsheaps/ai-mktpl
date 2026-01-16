# Hooks System

## Overview

This directory contains Claude Code hooks that run at various lifecycle points. Hooks can be configured in `.claude/settings.json` either:

1. **Via `run-hook.sh`** - Auto-discovers and runs all executable scripts in a subdirectory
2. **Via manual mapping** - Explicitly maps each hook script in settings.json

## run-hook.sh

The `run-hook.sh` script provides automatic hook discovery and execution.

**Usage:**

```bash
./run-hook.sh <hook-name> [additional-args...]
```

**Behavior:**

1. Finds all executable files in `.claude/hooks/<hook-name>/`
2. Runs them sequentially, passing Claude's stdin input to each
3. Exits with the last non-zero exit code (or 0 if all succeed)
4. Prints a warning if no executable scripts are found (but exits 0)

**Environment variables set:**

- `HOOK_NAME` - The hook type being run
- `HOOK_DIR` - Path to the hook directory
- `HOOK_ARGS` - Additional arguments passed after hook name
- `INPUT` - The JSON input from Claude (empty string if run from TTY)

## Hook Types

### SessionStart

Uses `run-hook.sh` for auto-discovery. All scripts in `.claude/hooks/session-start/` run for each session event.

```json
{
  "matcher": "startup",
  "hooks": [
    {
      "type": "command",
      "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/run-hook.sh session-start start"
    }
  ]
}
```

Matchers: `startup`, `resume`, `clear`, `compact`

### PreToolUse

Uses `run-hook.sh` with an empty matcher to run for all tool calls. Each script filters internally by tool type.

```json
{
  "matcher": "",
  "hooks": [
    {
      "type": "command",
      "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/run-hook.sh pre-tool-use"
    }
  ]
}
```

**Important:** PreToolUse hooks MUST:

1. Check `tool_name` internally and return `{"status": "approved"}` for tools they don't handle
2. Return valid JSON: `{"status": "approved"}` or `{"status": "rejected", "reason": "..."}`
3. Exit 0 (non-zero exits may cause issues)

## Directory Structure

```
.claude/hooks/
├── run-hook.sh              # Auto-discovery script
├── session-start/           # SessionStart hooks (auto-discovered)
│   └── *.sh
└── pre-tool-use/            # PreToolUse hooks (auto-discovered)
    ├── ensure-write-dir.sh  # Creates parent dirs for Write tool
    ├── safe-find-grep.sh    # Blocks dangerous find/grep patterns
    └── warn-force-push.sh   # Blocks force push without acknowledgment
```

## Writing New Hooks

### PreToolUse Hook Template

```bash
#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Only process specific tool(s)
if [[ "$TOOL_NAME" != "YourTool" ]]; then
    echo '{"status": "approved"}'
    exit 0
fi

# Your logic here...

# Return approved or rejected
echo '{"status": "approved"}'
# OR
# echo '{"status": "rejected", "reason": "Explanation"}'
```

### Making Scripts Executable

Scripts must be executable to be discovered by run-hook.sh:

```bash
chmod +x .claude/hooks/<hook-type>/your-script.sh
```

## Adding New Hooks

To add a new PreToolUse hook:

1. Create script in `.claude/hooks/pre-tool-use/`
2. Make it executable: `chmod +x your-hook.sh`
3. Ensure it checks `tool_name` and outputs proper JSON
4. It will be auto-discovered by run-hook.sh
