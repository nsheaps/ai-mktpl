# Task Management Rules

**CRITICAL:** Tasks are MANDATORY, not optional.

## Rule: Update Tasks BEFORE Any Tool Use

Before using ANY tool (except for simple conversational responses), you MUST first update your Tasks to reflect what you're about to do and any changes you've done since your last action.

### The Only Exception

Simple conversational responses that don't use tools are exempt. Everything else requires Task tracking.

### What This Means

1. **Before** using Read, Edit, Write, Bash, Grep, Glob, or ANY other tool, check your Tasks
2. If your Tasks don't reflect what you're about to do, update them FIRST
3. Never have stale Tasks that don't match your current work
4. Even "small" tasks like checking git status or reading a file should be tracked if they're part of a larger workflow

### Why This Matters

- Tasks give the user visibility into what you're doing
- They prevent drift from the actual task
- They create accountability for staying on track
- They help catch when you're doing work that wasn't requested

### Common Violations to Avoid

- Starting to fix something without adding it to Tasks first
- Doing "quick" side tasks without tracking them
- Having Tasks for Phase 2 while actually working on Phase 1
- Reverting commits or making corrections without updating Tasks to reflect the correction work

### Correct Pattern

```
1. User requests work
2. Update TaskWrite with planned tasks
3. Mark first task in_progress
4. Do the work (using tools)
5. Mark task completed
6. Repeat for next task
```

### Incorrect Pattern

```
1. User requests work
2. Start using tools immediately
3. Maybe update Tasks later (or forget)
```

## Rule: Capture User Messages Mid-Task

**CRITICAL:** When the user sends a message while you are "churning" (executing multiple tool calls), you MUST immediately add it to your TodoWrite.

### Why This Matters

The user cannot see your output while you're in the middle of tool execution. Their messages may contain:

- Corrections to what you're doing
- New requirements
- Questions that need answers
- Feedback on your approach

If you don't capture these as Tasks, you will forget them or fail to address them.

### Correct Pattern

```
1. You're mid-task, executing tools
2. User sends a message (appears as system-reminder)
3. IMMEDIATELY add a Task: "Address user message: <summary>"
4. Continue current work OR pivot based on urgency
5. Address the Task before considering work complete
```

### Incorrect Pattern

```
1. You're mid-task, executing tools
2. User sends a message
3. You see it but keep working
4. You forget to address it
5. User gets frustrated
```

## Rule: Delegate Tasks to Agents

**CRITICAL:** When working on a Task, prefer delegating to an appropriate agent rather than executing directly in your own context.

### Why This Matters

- Better isolation of work
- Clearer permissions boundaries
- More efficient context usage
- Agents can be resumed for related follow-up work
- Creates accountability trail for each task

### Correct Pattern

```
1. Break work into Tasks
2. For each Task, identify appropriate agent type:
   - Explore agent for codebase investigation
   - Plan agent for architectural decisions
   - general-purpose agent for implementation tasks
3. Launch agent with run_in_background: true if possible
4. Use TaskOutput to get results
5. Consider resuming the same agent for related follow-up
```

### When to Create New Agent Types

If no existing agent fits the task pattern well, ask the user:

> "This task seems specialized. Should I create a role-specific agent that captures the needed behaviors, or use the general-purpose agent?"

### Agent Resumption

When continuing work on a similar task, prefer resuming an existing agent by ID rather than starting fresh. This preserves context and reduces redundant exploration.
