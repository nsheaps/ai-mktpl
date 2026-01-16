#!/usr/bin/env bash
# PreToolUse hook: Warn about force push commands
# This hook initially blocks force push attempts and requires explicit acknowledgment

set -euo pipefail

# Parse the tool input from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only process Bash tool
if [[ "$TOOL_NAME" != "Bash" ]]; then
    echo '{"status": "approved"}'
    exit 0
fi

# Check if command contains force push flags
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*(--force|--force-with-lease|--force-if-includes|-f\s)'; then
    cat <<'EOF'
{
    "status": "rejected",
    "reason": "Force push detected. Rewriting shared history is dangerous.\n\n## Why this is blocked:\n- Once commits are pushed to a remote, others may have based work on them\n- Force pushing rewrites history and can cause lost commits for collaborators\n- It makes git history difficult to follow and debug\n\n## Alternatives to consider:\n1. **Create a new commit** that fixes the issue instead of amending\n2. **Use `git revert`** to undo changes without rewriting history\n3. **Merge instead of rebase** when integrating upstream changes\n\n## If you truly need to force push:\nAdd a comment to your command explaining WHY it's necessary, then retry:\n```bash\n# FORCE PUSH: <explain why this is safe/necessary>\ngit push --force-with-lease ...\n```\n\nThe hook will allow commands with this acknowledgment pattern."
}
EOF
    exit 0
fi

# Check if the force push has an acknowledgment comment
if echo "$COMMAND" | grep -qE '#\s*FORCE\s*PUSH:'; then
    echo '{"status": "approved"}'
    exit 0
fi

# Not a force push, allow it
echo '{"status": "approved"}'
