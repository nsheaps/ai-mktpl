#!/usr/bin/env bash
# triage-failure.sh — PostToolUseFailure hook
#
# When a tool fails, this hook asks Claude to triage whether the failure
# is something that can be learned from. If so, it suggests launching a
# background agent to update skills or coaching to prevent recurrence.
#
# Design philosophy:
# - Not all failures are learnable. TDD expects tests to fail before implementation.
# - But if a test was expected to pass and didn't, or a regression occurs, that IS learnable.
# - The triage uses a fast model (haiku) to make the determination cheaply.
# - If learnable, a system-reminder suggests launching a background opus agent
#   to update skills or rules.
#
# Input (stdin JSON): { tool_name, error, ... }
# Output: exit 2 with stderr system-reminder if failure is potentially learnable

set -euo pipefail

PLUGIN_NAME="brain"
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"

if ! plugin_is_enabled; then
  echo '{}'
  exit 0
fi

input="$(cat)"

tool_name="$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)"
error_msg="$(echo "$input" | jq -r '.error // empty' 2>/dev/null || true)"

# Skip if no meaningful error info
if [ -z "$tool_name" ] && [ -z "$error_msg" ]; then
  echo '{}'
  exit 0
fi

# Truncate error to avoid blowing up the system-reminder
max_error_len=500
if [ ${#error_msg} -gt $max_error_len ]; then
  error_msg="${error_msg:0:$max_error_len}..."
fi

# Emit a system-reminder that tells Claude to triage this failure.
# Claude (the main agent) will use a haiku subagent to decide if this is learnable,
# and if so, launch a background opus agent to help update skills/rules.
{
  cat <<REMINDER
<system-reminder>
A tool failure occurred. Triage whether this is a learnable failure.

**Tool:** ${tool_name}
**Error:** ${error_msg}

Use a haiku agent to quickly determine:
1. Is this failure something that can be learned from to prevent recurrence?
2. Or is it expected/intentional (e.g., TDD test failing before implementation, permission denied for valid reasons)?

**Learnable failures include:**
- A test you expected to pass but it failed (implementation error)
- A regression where existing tests broke due to your changes
- Repeated mistakes in tool usage (wrong flags, bad paths, syntax errors)
- Build failures from code you just wrote
- Failures that indicate a misunderstanding of the codebase or API

**NOT learnable (expected/intentional):**
- TDD: writing a test before implementing the feature (test SHOULD fail)
- Permission prompts the user denied (that's user choice, not a mistake)
- Network/infrastructure failures outside your control
- Intentional destructive testing

If the haiku agent determines this IS learnable, launch a background opus agent to:
1. Analyze what went wrong and why
2. Check if there are existing skills or rules that should have prevented this
3. If not, draft updates to skills, rules, or CLAUDE.md to prevent recurrence
4. Use the /correct-behavior command pattern from the correct-behavior plugin as a reference for how to structure behavior corrections

Do NOT block on this — launch it in the background and continue your work.
</system-reminder>
REMINDER
} >&2

exit 2
