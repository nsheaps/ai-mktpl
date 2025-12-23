# Todo Management Rules

**CRITICAL:** Todos are MANDATORY, not optional.

## Rule: Update Todos BEFORE Any Tool Use

Before using ANY tool (except for simple conversational responses), you MUST first update your todos to reflect what you're about to do.

### The Only Exception

Simple conversational responses that don't use tools are exempt. Everything else requires todo tracking.

### What This Means

1. **Before** using Read, Edit, Write, Bash, Grep, Glob, or ANY other tool, check your todos
2. If your todos don't reflect what you're about to do, update them FIRST
3. Never have stale todos that don't match your current work
4. Even "small" tasks like checking git status or reading a file should be tracked if they're part of a larger workflow

### Why This Matters

- Todos give the user visibility into what you're doing
- They prevent drift from the actual task
- They create accountability for staying on track
- They help catch when you're doing work that wasn't requested

### Common Violations to Avoid

- Starting to fix something without adding it to todos first
- Doing "quick" side tasks without tracking them
- Having todos for Phase 2 while actually working on Phase 1
- Reverting commits or making corrections without updating todos to reflect the correction work

### Correct Pattern

```
1. User requests work
2. Update TodoWrite with planned tasks
3. Mark first task in_progress
4. Do the work (using tools)
5. Mark task completed
6. Repeat for next task
```

### Incorrect Pattern

```
1. User requests work
2. Start using tools immediately
3. Maybe update todos later (or forget)
```
