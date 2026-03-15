#!/usr/bin/env bash
# load-behavior-skill.sh — UserPromptSubmit hook
#
# On each user prompt, reminds the agent that the correct-behavior skill
# is available for fixing behavioral mistakes. This pairs with the
# PostToolUseFailure triage hook: when a learnable failure is detected,
# the agent knows the correct-behavior command exists to formalize the fix.
#
# Input (stdin JSON): { prompt, ... }
# Output: exit 0 with empty JSON (informational only)

set -euo pipefail

PLUGIN_NAME="brain"
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"

if ! plugin_is_enabled; then
  echo '{}'
  exit 0
fi

# Read and discard stdin (required for hook protocol)
cat > /dev/null

# Check if correct-behavior plugin is installed by looking for its command
# This avoids referencing something that isn't available
correct_behavior_available=false

# Check in the plugin marketplace (installed plugins)
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  # The correct-behavior plugin would be in a sibling plugin directory
  # When installed, each plugin gets its own CLAUDE_PLUGIN_ROOT
  # We check if the command is available via the marketplace
  plugin_dir="$(dirname "${CLAUDE_PLUGIN_ROOT}")"
  if [ -f "${plugin_dir}/correct-behavior/commands/correct-behavior.md" ]; then
    correct_behavior_available=true
  fi
fi

# Also check user-level commands
if [ -f "${HOME}/.claude/commands/correct-behavior.md" ]; then
  correct_behavior_available=true
fi

if [ "$correct_behavior_available" = "true" ]; then
  {
    cat <<'REMINDER'
<system-reminder>
The /correct-behavior command is available. When you make behavioral mistakes or when a learnable failure is detected by the PostToolUseFailure hook, you can use this command to formally correct the behavior and update rules/skills to prevent recurrence. Use it when a background agent identifies a pattern that should be codified into rules.
</system-reminder>
REMINDER
  } >&2
fi

echo '{}'
