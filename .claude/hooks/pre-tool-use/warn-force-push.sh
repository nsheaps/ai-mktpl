#!/usr/bin/env bash
# PreToolUse hook: Warn about force push commands
# This hook initially blocks force push attempts and requires explicit acknowledgment

set -euo pipefail
source "$(dirname "$0")/../lib/pretooluse.sh"

# Parse the tool input from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only process Bash tool
if [[ "$TOOL_NAME" != "Bash" ]]; then
    allow
fi

# Check for acknowledgment comment FIRST (before rejecting force pushes)
if echo "$COMMAND" | grep -qE '#\s*FORCE\s*PUSH:'; then
    allow
fi

# Check if command contains force push flags (reject if no acknowledgment)
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*(--force|--force-with-lease|--force-if-includes|-f\s)'; then
    deny "Force push detected. Rewriting shared history is dangerous.

## Why this is blocked:
- Once commits are pushed to a remote, others may have based work on them
- Force pushing rewrites history and can cause lost commits for collaborators
- It makes git history difficult to follow and debug

## Alternatives to consider:
1. **Create a new commit** that fixes the issue instead of amending
2. **Use git revert** to undo changes without rewriting history
3. **Merge instead of rebase** when integrating upstream changes

## If you truly need to force push:
Add a comment to your command explaining WHY it's necessary, then retry:
\`\`\`bash
# FORCE PUSH: <explain why this is safe/necessary>
git push --force-with-lease ...
\`\`\`

The hook will allow commands with this acknowledgment pattern."
fi

# Not a force push, allow it
allow
