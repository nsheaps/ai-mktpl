#!/usr/bin/env bash
# PreToolUse hook: Reject bash commands with && or | chaining
# Chained commands cannot have proper permissions checked, so we enforce single-command execution.
#
# Blocked patterns:
# - && (command chaining)
# - | (piping output)
#
# Allowed patterns:
# - || (error handling/fallback - this is acceptable)
# - ; (sequential execution - blocked by separate check)
# - Single commands with arguments

set -euo pipefail

# Find the library relative to the plugin root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Source the shared pretooluse library from the global hooks
if [[ -f "$HOME/.ai/.claude/hooks/lib/pretooluse.sh" ]]; then
    source "$HOME/.ai/.claude/hooks/lib/pretooluse.sh"
else
    # Fallback: define minimal functions if library not found
    deny() {
        local reason="$1"
        echo "{\"hookSpecificOutput\":{\"permissionDecision\":\"deny\",\"permissionDecisionReason\":$(echo "$reason" | jq -Rs .)}}"
        exit 0
    }
    allow() {
        echo '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
        exit 0
    }
fi

# Parse the tool input from stdin
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Skip empty commands
if [[ -z "$COMMAND" ]]; then
    allow
fi

# Check for bypass acknowledgment comment FIRST
# Users can add this comment to explicitly allow chaining when necessary
if echo "$COMMAND" | grep -qE '#\s*CHAINED:\s*'; then
    allow
fi

# Check for && chaining (but not inside quoted strings - simple heuristic)
# We look for && that's not inside quotes
if echo "$COMMAND" | grep -qE '&&'; then
    # Simple check: if && appears, reject
    # Note: This may have false positives inside quoted strings, but errs on the side of caution
    deny "**Command chaining with && is not allowed.**

## Why this is blocked:
- Permission systems can only evaluate individual commands, not chains
- The second command in \`cmd1 && cmd2\` runs only if cmd1 succeeds
- This makes it impossible to properly review what will actually execute
- Chained commands bypass the approval workflow

## What to do instead:

### Option 1: Run commands separately
Run each command individually so permissions can be checked for each:
\`\`\`bash
command1
\`\`\`
Then in a separate call:
\`\`\`bash
command2
\`\`\`

### Option 2: Redirect output to a file
If you need to capture output for the next command:
\`\`\`bash
command1 > /tmp/output.txt
\`\`\`
Then read the file with the Read tool, or:
\`\`\`bash
command2 < /tmp/output.txt
\`\`\`

### Option 3: Write a script for review
For complex multi-step operations, write a shell script:
\`\`\`bash
#!/bin/bash
command1
command2
command3
\`\`\`
Save it, let the user review it, then execute the script.

### Option 4: Acknowledge and bypass (if truly necessary)
Add a comment explaining why chaining is required:
\`\`\`bash
# CHAINED: Brief explanation of why this is safe/necessary
command1 && command2
\`\`\`"
fi

# Check for | piping (but not ||)
# Remove || first to avoid false positives, then check for remaining |
COMMAND_NO_OR=$(echo "$COMMAND" | sed 's/||/__OR_PLACEHOLDER__/g')
if echo "$COMMAND_NO_OR" | grep -qF '|'; then
    deny "**Piping with | is not allowed.**

## Why this is blocked:
- Permission systems can only evaluate the first command in a pipeline
- The piped commands (\`cmd1 | cmd2\`) execute as a chain
- You cannot review or approve what \`cmd2\` does with the output
- This creates a security blind spot in the approval workflow

## What to do instead:

### Option 1: Redirect to file, then process
Capture the output to a file first:
\`\`\`bash
command1 > /tmp/output.txt
\`\`\`
Then use the Read tool to examine the output, or process it separately:
\`\`\`bash
command2 < /tmp/output.txt
\`\`\`

### Option 2: Use dedicated tools
Instead of piping to grep/sed/awk, use Claude Code's built-in tools:
- **Grep tool** for searching file contents
- **Read tool** for viewing files
- **Edit tool** for modifying files

### Option 3: Write a script for review
For complex pipelines, write a shell script:
\`\`\`bash
#!/bin/bash
output=\$(command1)
echo \"\$output\" | command2 | command3
\`\`\`
Save it, let the user review it, then execute the script.

### Option 4: Acknowledge and bypass (if truly necessary)
Add a comment explaining why piping is required:
\`\`\`bash
# CHAINED: Brief explanation of why this is safe/necessary
command1 | command2
\`\`\`"
fi

# Check for ; sequential execution (also problematic for permissions)
if echo "$COMMAND" | grep -qE ';[^;]|;$'; then
    deny "**Sequential execution with ; is not allowed.**

## Why this is blocked:
- The ; operator runs commands sequentially regardless of success/failure
- Permission systems cannot properly evaluate chains of commands
- Each command in \`cmd1; cmd2; cmd3\` should be reviewed separately

## What to do instead:

### Option 1: Run commands separately
Execute each command in its own Bash call:
\`\`\`bash
command1
\`\`\`
Then:
\`\`\`bash
command2
\`\`\`

### Option 2: Write a script for review
For multi-step operations, write a shell script that can be reviewed:
\`\`\`bash
#!/bin/bash
command1
command2
command3
\`\`\`

### Option 3: Acknowledge and bypass (if truly necessary)
Add a comment explaining why sequential execution is required:
\`\`\`bash
# CHAINED: Brief explanation of why this is safe/necessary
command1; command2
\`\`\`"
fi

# Command passed all checks
allow
