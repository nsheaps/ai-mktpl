# Consolidated Task Management Plugin

**Status**: Draft
**Author**: Bugs Bunny (Software Engineer)
**Date**: 2026-02-17

## Problem

The ai-mktpl repository currently has three separate plugins that each address a narrow slice of task/todo management:

1. **todo-plus-plus** — Enforces commit-on-complete via `TaskCompleted` hook and injects ephemeral session awareness via `SessionStart` prompt hook
2. **todo-sync** — Syncs todo files from `~/.claude/todos/` to project `.claude/todos/` via `PostToolUse:TodoWrite` hook, with `SessionStart`/`UserPromptSubmit` hooks for gitignore initialization
3. **task-parallelization** — Skill-only plugin providing guidance for parallelizing Task tool calls (no hooks)

### Issues with Current State

- **Fragmented behavior**: Three plugins must all be installed to get complete task management. Users may install one and miss the others.
- **Hook conflicts**: Multiple plugins hooking into `SessionStart` and `PostToolUse` independently increases overhead and risk of ordering issues.
- **Missing capabilities**: Several useful task management behaviors identified in user research ([obsidian ramblings](https://github.com/nsheaps/obsidian-vaults)) are not implemented anywhere:
  - Pre-tool-use rejection when no active tasks exist (enforcement)
  - Stop hook rejection when active tasks remain (prevents premature exit)
  - Task "sleep" state for incomplete work that persists across sessions
  - Structural-thinking decomposition of user prompts into tasks/stories/requirements
  - Using task updates to segment conversations for searchability

## Requirements

### Must Have (MVP)

1. **Single plugin** (`task-management`) that replaces `todo-plus-plus`, `todo-sync`, and `task-parallelization`
2. **Commit enforcement** on task completion (from todo-plus-plus `TaskCompleted` hook)
3. **Ephemeral session awareness** — remind agent that tasks are session-scoped and to persist important work (from todo-plus-plus `SessionStart` hook)
4. **Task parallelization guidance** as a skill (from task-parallelization)
5. **Pre-tool-use task check** — `PreToolUse` hook that warns (not blocks) when no active tasks exist, nudging the agent to create tasks before working
   - Source: [obsidian ramblings, line 112](https://github.com/nsheaps/obsidian-vaults)
6. **Stop hook guard** — `Stop` hook that warns when active (in_progress) tasks remain, prompting the agent to mark them complete or explicitly defer
   - Source: [obsidian ramblings, lines 113-116](https://github.com/nsheaps/obsidian-vaults)

### Should Have (Post-MVP)

7. **Todo file sync** — sync task state to project `.claude/` directory for persistence (from todo-sync)
8. **Conversation segmentation** — use task transitions (start/complete) as logical boundaries in conversation history for improved searchability
   - Source: [obsidian ramblings, line 109](https://github.com/nsheaps/obsidian-vaults)

### Could Have (Future)

9. **Structural-thinking decomposition** — on each user prompt, break the request into task/story/deliverables/requirements structure
   - Source: [obsidian ramblings, line 128](https://github.com/nsheaps/obsidian-vaults)
   - Note: This may be better as a separate plugin since it's a distinct concern from task lifecycle management
10. **Task "sleep" state** — mark incomplete tasks as sleeping with context for next session pickup
    - Source: [obsidian ramblings, lines 113-116](https://github.com/nsheaps/obsidian-vaults)

### Must NOT

- Break existing behavior for users who currently have todo-plus-plus, todo-sync, or task-parallelization installed
- Introduce hard blocks that prevent agents from working (all enforcement should warn/nudge, not reject)

## Technical Design

### Plugin Structure

```
plugins/task-management/
  plugin.json
  skills/
    task-parallelization/
      SKILL.md                   # Migrated from task-parallelization plugin
    task-management/
      SKILL.md                   # Consolidated guidance: lifecycle, naming, persistence
  hooks/
    session-start.md             # Ephemeral awareness prompt (from todo-plus-plus)
    task-completed.sh            # Commit enforcement (from todo-plus-plus)
    pre-tool-use-task-check.md   # Warn if no active tasks (new, from ramblings)
    stop-active-tasks-guard.md   # Warn if tasks still active (new, from ramblings)
```

### Hook Design

#### `session-start.md` (SessionStart, prompt)

Migrated from todo-plus-plus. Injects system prompt reminding agent that:
- Tasks are ephemeral and scoped to the session
- Important work should be persisted to files
- Use TaskCreate before starting non-trivial work

#### `task-completed.sh` (TaskCompleted, command)

Migrated from todo-plus-plus. On task completion:
- Checks if there are uncommitted changes related to the completed task
- If so, prompts for commit (via output message, not interactive)

#### `pre-tool-use-task-check.md` (PreToolUse, prompt)

New hook. Triggers on tool use when no in_progress tasks exist:
- Fires on: Edit, Write, Bash (tools that make changes)
- Skips: Read, Grep, Glob, WebFetch (read-only tools)
- Output: Gentle reminder to create/activate a task before proceeding
- Does NOT block execution — advisory only

#### `stop-active-tasks-guard.md` (Stop, prompt)

New hook. Triggers when agent attempts to stop with active tasks:
- Checks for any tasks with status `in_progress`
- If found: reminds agent to mark them complete or explicitly defer with notes
- Does NOT block the stop — advisory only

### Migration Plan

1. Create the new `task-management` plugin
2. Mark `todo-plus-plus`, `todo-sync`, and `task-parallelization` as deprecated in their READMEs
3. Add a note to each deprecated plugin pointing to `task-management`
4. Do NOT delete the old plugins immediately — users may have them installed

### What's NOT Included (and Why)

- **todo-sync file syncing**: Deferred to post-MVP. The current TaskCreate/TaskUpdate tools don't write to files, so syncing requires custom file I/O that adds complexity. Will revisit when task persistence patterns stabilize.
- **Structural-thinking decomposition**: Better as a separate plugin — it's about request analysis, not task lifecycle. Noted for future consideration.
- **Hard blocking hooks**: All hooks are advisory. Hard blocks (rejecting tool use, preventing stop) create poor UX and can trap agents in loops.

## References

- [todo-plus-plus plugin](https://github.com/nsheaps/ai-mktpl/tree/main/plugins/todo-plus-plus)
- [todo-sync plugin](https://github.com/nsheaps/ai-mktpl/tree/main/plugins/todo-sync)
- [task-parallelization plugin](https://github.com/nsheaps/ai-mktpl/tree/main/plugins/task-parallelization)
- [AI ramblings (obsidian-vaults)](https://github.com/nsheaps/obsidian-vaults) — lines 109, 112-116, 128
- [Claude Code hooks documentation](https://code.claude.com/docs/en/hooks)
- [Claude Code plugins documentation](https://code.claude.com/docs/en/plugins)
