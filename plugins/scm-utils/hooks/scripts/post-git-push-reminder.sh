#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook: After a git push, remind the agent to update PR metadata.
# Reads hook input JSON from stdin, checks if the Bash command was a git push,
# and outputs a systemMessage reminder if so.

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Check if the command contains "git push"
if [[ "$command" == *"git push"* ]]; then
  jq -n '{
    "systemMessage": "Don'\''t forget to update the PR title and description to include details about any changes you just made. If you'\''re finished making changes (as in, all requests are now complete and you are no longer iterating on it, not just you'\''ve pushed a single commit), make sure to re-request review so that reviewers know to review your code. If you'\''ve iterated on it enough and you think it'\''s probably ready to be merged, regardless of if you'\''ve gotten the review yet, make sure the PR is OPEN, not DRAFT"
  }'
fi
