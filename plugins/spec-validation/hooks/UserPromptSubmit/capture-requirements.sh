#!/bin/bash
# UserPromptSubmit hook: Adds spec-based development guidance to user prompts
#
# This hook injects instructions for Claude to:
# 1. Use explore/plan agents for new feature requests
# 2. Capture requirements into spec files
# 3. Move existing specs to drafts before updating
# 4. Keep specs minimal and user-focused

# Read the user's prompt from stdin
USER_PROMPT=$(cat)

# Check if this looks like a feature request or implementation task
# (not a simple question or clarification)
if echo "$USER_PROMPT" | grep -qiE "(add|create|implement|build|develop|make|write|fix|update|change|modify|refactor)"; then

  # Output the modified prompt with spec-based development instructions
  cat << 'SPEC_GUIDANCE'
<spec-based-development>
For this request, follow spec-based development practices:

1. **Before implementation**: If this is a non-trivial feature or change:
   - Use the Explore agent to understand the relevant codebase areas
   - Use the Plan agent to design the implementation approach
   - Create/update a spec file in `docs/specs/` capturing ONLY what the user requested

2. **Spec file rules**:
   - If a spec already exists in `docs/specs/`, move it to `docs/specs/draft/` first
   - Keep specs concise: only include requirements from the user's prompt or clarifications
   - Use format: `docs/specs/<feature-name>.md`
   - Commit spec changes BEFORE starting implementation work

3. **Spec file format**:
   ```markdown
   # Feature Name

   ## Requirements
   - [Bullet points of what user requested]

   ## Acceptance Criteria
   - [How to verify the feature works]

   ## Notes
   - [Any clarifications from conversation]
   ```

4. **Validation**: After completing work, verify against the spec's acceptance criteria
</spec-based-development>

SPEC_GUIDANCE

fi

# Always output the original prompt
echo "$USER_PROMPT"
