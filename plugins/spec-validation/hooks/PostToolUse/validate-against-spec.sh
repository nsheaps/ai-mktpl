#!/bin/bash
# PostToolUse hook: Reminds Claude to validate changes against spec
#
# Triggers after TodoWrite tool to remind about:
# 1. Validating changes against the spec
# 2. Running tests to verify implementation
# 3. Checking CI after pushing (but not waiting)

# Read tool info from stdin
TOOL_INFO=$(cat)

# Extract tool name from the input
TOOL_NAME=$(echo "$TOOL_INFO" | jq -r '.tool_name // empty' 2>/dev/null)

# Only act on TodoWrite tool calls
if [ "$TOOL_NAME" = "TodoWrite" ]; then
  # Check if there are any spec files in docs/specs/
  SPEC_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/docs/specs"

  if [ -d "$SPEC_DIR" ] && [ "$(ls -A "$SPEC_DIR" 2>/dev/null | grep -v drafts)" ]; then
    cat << 'VALIDATION_REMINDER'

<spec-validation-reminder>
**Spec Validation Checklist:**
- [ ] Verify your changes satisfy ALL requirements in `docs/specs/*.md`
- [ ] Run unit tests locally to confirm implementation works
- [ ] Ensure tests cover the acceptance criteria from the spec
- [ ] Push code and let CI run (don't wait for completion)
- [ ] If marking a task complete, confirm it meets the spec's acceptance criteria

**Note:** Most changes should include unit tests. If you haven't added tests yet, consider what scenarios the spec requires to be validated.
</spec-validation-reminder>

VALIDATION_REMINDER
  fi
fi

# Exit successfully (don't block the tool)
exit 0
