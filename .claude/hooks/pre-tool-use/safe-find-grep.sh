#!/usr/bin/env bash
set -euo pipefail

# Read the command from stdin JSON
cmd=$(jq -r '.tool_input.command // ""')

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
        echo "Blocked: Command matches dangerous pattern '$pat'. Use find/grep for searching only, not for executing commands." >&2
        exit 2
    fi
done

exit 0
