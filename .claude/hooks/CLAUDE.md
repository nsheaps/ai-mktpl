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

Currently uses **manual mapping** (not run-hook.sh). Each hook is explicitly configured:

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "bash ${CLAUDE_PROJECT_DIR}/.claude/hooks/pre-tool-use/warn-force-push.sh"
    }
  ]
}
```

**Note:** PreToolUse hooks should check the tool type internally and return `{"status": "approved"}` for tools they don't handle. This allows them to work with either manual mapping or auto-discovery via run-hook.sh.

## Directory Structure

```
.claude/hooks/
├── run-hook.sh              # Auto-discovery script
├── session-start/           # SessionStart hooks (auto-discovered)
│   └── *.sh
└── pre-tool-use/            # PreToolUse hooks (manually mapped)
    ├── ensure-write-dir.sh  # Creates parent dirs for Write tool
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

## Migrating to Auto-Discovery

To migrate PreToolUse from manual mapping to auto-discovery:

1. Ensure all scripts in `pre-tool-use/` check tool type internally
2. Replace manual mappings with single run-hook.sh call:
   ```json
   "PreToolUse": [{
     "matcher": "*",
     "hooks": [{
       "type": "command",
       "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/run-hook.sh pre-tool-use"
     }]
   }]
   ```
