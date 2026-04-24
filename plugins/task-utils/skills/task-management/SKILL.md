---
name: task-management
description: Task lifecycle management for Claude Code agents. Use this skill when working with TaskCreate, TaskUpdate, TaskList, TaskGet, or when asked about task naming conventions, the task lifecycle, or when to delegate tasks to sub-agents.
---

# Task Management Skill

This skill covers the full task lifecycle for Claude Code agents: when to create tasks, how to name them, how to track their state, and when to delegate to sub-agents.

## Core Rule: Always Use Tasks for Action Requests

ALWAYS use TaskCreate to track your tasks on EVERY action request from the user. Even if it is a simple, one-off task.

**Exception**: When the user asks a question, answer it first. Do NOT create tasks for questions — only create tasks after the user confirms they want action.

## When and How to Use TaskCreate

### Trigger: Any action request from the user

```
User: "Fix the bug in the login flow"
→ TaskCreate: { subject: "#23: Fix the bug in the login flow" }
```

### Do NOT create tasks for:

- Questions ("What is X?", "Why does Y happen?")
- Conversational responses
- Clarifications

## Task Naming Conventions

Tasks MUST always include the task ID in the subject and activeForm.

**GOOD:**
```
#23: Fix the bug in the login flow
```

**BAD:**
```
Fix the bug in the login flow
```

### Ticket/PR References

- If a task directly relates to a ticket in an external tracking system, include the ticket number in the subject.
- If a task relates to a PR, include the PR number if the user is referencing change sets by PR number.

**Examples:**
```
#23: [GH-456] Fix the authentication bug
#24: [PR #789] Review and address feedback
```

## Task Lifecycle

```
created → in_progress → completed
                      → cancelled
```

1. **created**: Task is defined but work has not started
2. **in_progress**: Actively working on this task right now
3. **completed**: Work is done, changes are committed and pushed
4. **cancelled**: Task is no longer needed

### Rules

- Only ONE task should be `in_progress` at a time (unless delegated to parallel sub-agents)
- Use TaskUpdate to change status before and after each phase
- Always commit and push before marking a task `completed`
- Update Tasks BEFORE any tool use — never have stale Tasks

## Keeping Tasks Up to Date

Before using ANY tool (Read, Edit, Write, Bash, Grep, etc.), you MUST first check your Tasks:

1. If Tasks don't reflect what you're about to do, update them first
2. Never have stale Tasks that don't match your current work
3. Mark the current task `in_progress` before starting work

## Delegating Tasks to Sub-Agents

When working on a task, prefer delegating to an appropriate sub-agent rather than executing directly in your own context.

### Why Delegate

- Better isolation of work
- Clearer permission boundaries
- More efficient context usage
- Agents can be resumed for related follow-up work

### When to Delegate

| Task Type | Delegate? |
|-----------|-----------|
| Codebase investigation / exploration | Yes — use Explore agent with haiku |
| Architectural decisions | Yes — use Plan agent |
| Implementation tasks (3+ files) | Yes — use general-purpose agent |
| Simple 1-file edits | No — execute directly |
| Quick lookups | No — execute directly |

### Sub-Agent Prompt Pattern

When delegating, always tell the sub-agent:

1. What task it is working on (include task ID)
2. What to produce or change
3. Where to save any output
4. NOT to return large outputs inline — save to files and summarize

```
You are working on Task #23: Fix the authentication bug.

Your job: [specific instructions]

Output: Save findings to docs/research/auth-bug-investigation.md
Return: A summary of what you changed and any file paths created/modified.
Do NOT return the full file contents inline.
```

### Agent Resumption

When continuing work on a related task, prefer resuming an existing agent by ID rather than starting fresh. This preserves context and reduces redundant exploration.

## Task List Hygiene

- Review TaskList at the start of each session
- Archive or cancel stale tasks that are no longer relevant
- Never let completed tasks sit as `in_progress`
- Use TaskGet to read full task details before resuming work

## When Tasks Are Blocked

If you cannot complete a task (blocked by dependency, missing info, external factor):

1. Leave the task `in_progress` (it's still your responsibility)
2. Create a new task for the blocker: "#24: Unblock task #23 — [reason]"
3. Resolve the blocker first, then return to the original task

## Task Completion Checklist

Before marking a task `completed`:

- [ ] The original user request is fully satisfied
- [ ] Changes have been tested and validated
- [ ] Code review feedback has been addressed
- [ ] All changes are committed and pushed to remote
- [ ] No known issues remain

## Related Skills

- `task-parallelization` — how to run multiple tasks concurrently for batch operations
