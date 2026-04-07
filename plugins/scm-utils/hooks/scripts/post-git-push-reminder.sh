#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook: After a git push, remind the agent to update PR metadata.
# Reads hook input JSON from stdin, checks if the Bash command was a git push,
# and outputs a systemMessage reminder if so.

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Match "git push" as an actual command invocation, not a substring in strings/comments
if echo "$command" | grep -qE '(^|\s|&&|\|\||;)git\s+push(\s|$)'; then
  message="You just pushed. Update the PR title and description to reflect cumulative changes, then re-request review if all work is complete."
  jq -n --arg msg "$message" '{"systemMessage": $msg}'
fi
