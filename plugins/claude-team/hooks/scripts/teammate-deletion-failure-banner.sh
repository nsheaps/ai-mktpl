#!/usr/bin/env bash
# teammate-deletion-failure-banner.sh — PostToolUseFailure hook
#
# When a tool failure looks related to teammate deletion/removal/shutdown,
# prints a prominent banner explaining how to manually clean up the team config.
#
# Input (stdin JSON): { tool_name, error, is_interrupt, team_name, ... }
# Output: exit 2 with stderr to show informational message to Claude
set -euo pipefail

input="$(cat)"

tool_name="$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)"
error_msg="$(echo "$input" | jq -r '.error // empty' 2>/dev/null || true)"
team_name="$(echo "$input" | jq -r '.team_name // empty' 2>/dev/null || true)"

# Only trigger for team-related failures
# Check tool name and error message for teammate deletion keywords
is_team_related=false

case "$tool_name" in
  TeamDelete|SendMessage|TaskStop)
    is_team_related=true
    ;;
esac

if [ "$is_team_related" = "false" ]; then
  # Check error message for team-related keywords
  if echo "$error_msg" | grep -qiE 'team|teammate|member|shutdown|spawn|agent'; then
    is_team_related=true
  fi
fi

if [ "$is_team_related" = "false" ]; then
  exit 0
fi

# Determine team config path
team_config=""
if [ -n "$team_name" ]; then
  team_config="$HOME/.claude/teams/${team_name}/config.json"
fi

# Print the banner
{
  echo ""
  echo "╔══════════════════════════════════════════════════════════════════╗"
  echo "║                   TEAMMATE OPERATION FAILED                    ║"
  echo "╠══════════════════════════════════════════════════════════════════╣"
  echo "║                                                                ║"
  echo "║  A team operation failed. This can happen when a teammate's    ║"
  echo "║  process has crashed or become unresponsive.                   ║"
  echo "║                                                                ║"
  echo "║  Tool: $(printf '%-55s' "${tool_name:-unknown}")║"
  if [ -n "$error_msg" ]; then
    # Truncate error to fit banner width
    short_error="${error_msg:0:55}"
    echo "║  Error: $(printf '%-53s' "$short_error")║"
  fi
  echo "║                                                                ║"
  echo "║  TO FIX: Manually remove the stale member entry from:         ║"
  if [ -n "$team_config" ] && [ -f "$team_config" ]; then
    echo "║                                                                ║"
    echo "║    $team_config"
  else
    echo "║                                                                ║"
    echo "║    ~/.claude/teams/{team-name}/config.json                    ║"
  fi
  echo "║                                                                ║"
  echo "║  Edit the file and remove the member object from the           ║"
  echo "║  \"members\" array for the crashed teammate.                     ║"
  echo "║                                                                ║"
  echo "║  IF YOU DON'T: The next time you spawn a teammate with the     ║"
  echo "║  same name, it will get a \"-2\" suffix (e.g. \"Bugs B-2\")       ║"
  echo "║  because the original entry still exists in the config.        ║"
  echo "║                                                                ║"
  echo "╚══════════════════════════════════════════════════════════════════╝"
  echo ""
} >&2

exit 2
