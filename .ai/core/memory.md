# Memory Management
via the Serena MCP server

## Critical Commands & When to Use

**At conversation start:**
- `activate_project` - Switch to correct project context
- `check_onboarding_performed` - Verify `.serena/` setup. `onboard` if not already done. Don't forget to commit the onboarded stuff.

**When project is not activated during work:**
- If you discover no serena project is active while working (error: "No active project"), STOP and ASK the user if the current working directory should be activated/created/onboarded as a serena project
- Do not continue with mixed serena/non-serena tooling - either activate serena properly or use standard tools only
- Never assume the user wants serena activated - always ask first

**Before major tasks:**
- `think_about_collected_information` - Consider findings & needed changes
- `list_memories` - Check available project knowledge
- `read_memory` - Load specific context

**During/after work:**
- `think_about_collected_information` - Consider findings & needed changes
- `think_about_task_adherence` - Consider if doing task correctly. MUST call after each task.
- `write_memory` - Capture discoveries & insights
- `think_about_whether_you_are_done` - After finishing chunks

## CRITICAL: Memory Persistence

**AFTER EACH `write_memory`**: Memory files in `.serena/` must be committed and pushed. If on default branch, ASK about creating a branch first.

For complete system details, workflows, and context management: `@../docs/excerpts/memory-management.md`
