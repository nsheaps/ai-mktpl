#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../lib/pretooluse.sh"

# Read JSON input from stdin
INPUT=$(cat)

# Extract tool name
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Only process Bash tool calls
if [[ "$TOOL_NAME" != "Bash" ]]; then
    allow
fi

# Read the command from input JSON
cmd=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Patterns to block - these allow code execution through find/grep
deny_patterns=(
    # find execution flags
    'find\s.*-exec'
    'find\s.*-execdir'
    'find\s.*-ok\b'
    'find\s.*-okdir'
    # Piping to shells/execution
    '\|\s*(sh|bash|zsh|dash|ksh)\b'
    '\|\s*xargs\s.*sh\b'
    '\|\s*xargs\s.*bash\b'
    '\|\s*xargs\s+-I.*sh\s+-c'
    '\|\s*eval\b'
    '\|\s*source\b'
    '\|\s*\.\s+'
)

for pat in "${deny_patterns[@]}"; do
    if echo "$cmd" | grep -Eiq "$pat"; then
        deny "Command matches dangerous pattern '$pat'. Use find/grep for searching only, not for executing commands."
    fi
done

allow
