# Task Planning Rules

How to approach complex tasks systematically.

## Rule: Explore Before Implementing

When you first receive a user request that:

- Requires multiple tools, OR
- Involves complex edits (more than 2 files), OR
- Has unclear scope or dependencies

**ALWAYS use the Explore and Plan agents first** to understand the full scope before acting.

### Why This Matters

- Prevents wasted effort on incorrect assumptions
- Surfaces hidden dependencies early
- Gives you accurate context before committing to a plan
- Avoids mid-task pivots that leave partial work

### Exploration Workflow

```
1. Receive user request
2. Assess complexity:
   - Simple (1-2 files, clear scope) → Proceed directly
   - Complex (3+ files, unclear scope) → Use Explore agent
3. Explore agent investigates:
   - Related files and dependencies
   - Existing patterns to follow
   - Potential conflicts or blockers
4. Review Explore agent findings
5. Then proceed to planning
```

## Rule: Plan Before Executing

After exploration (or for moderately complex tasks), use the **Plan agent** to create a structured implementation plan.

### When to Use Plan Agent

- New features with architectural decisions
- Refactoring across multiple files
- Tasks with multiple valid approaches
- Any task where you'd otherwise use AskUserQuestion to clarify approach

### Planning Workflow

```
1. Launch Plan agent with task context
2. Agent creates structured plan covering:
   - Files to modify
   - Order of operations
   - Potential risks
   - Testing approach
3. Review and save the plan
4. Get user approval if needed
5. Execute plan step by step
```

## Rule: Persist Plans for Reference

**CRITICAL:** Save plans to files in the repository so you can re-visit and check progress.

### Standard Locations

| Content Type  | Location                                  |
| ------------- | ----------------------------------------- |
| Task plans    | `docs/scratch/plans/<request-summary>.md` |
| Task list     | `docs/scratch/todo.md`                    |
| Scratch notes | `docs/scratch/note-<topic>.md`            |
| Research      | `docs/research/<topic>.md`                |
| Product specs | `docs/specs/draft/<feature>.md`           |

### Why Persist to Files

- Never trust memory or conversation history for important details
- Files survive context resets and session boundaries
- Creates audit trail of decisions and progress
- Allows easy review and course correction

### Task List File

Maintain `docs/scratch/todo.md` as a persistent task list:

```markdown
# Current Tasks

- [x] Explore codebase for authentication patterns
- [x] Create implementation plan
- [ ] Implement login endpoint
- [ ] Add authentication middleware
- [ ] Write tests
- [ ] Update API documentation

## Notes

- Using JWT tokens per existing pattern in auth.ts
- Need to coordinate with frontend team on token refresh
```

**Update this file before and after each task completes.**

## Rule: STEM Mindset

Apply scientific rigor to problem-solving:

> "The only difference between screwing around and science is writing it down."

### What This Means

1. **Document your hypotheses** before testing them
2. **Record observations** as you explore
3. **Track what you tried** and what happened
4. **Capture decisions** and their rationale
5. **Note unexpected findings** for future reference

### Practical Application

- When debugging: Write down what you think the problem is before investigating
- When exploring: Keep notes on what you find, even tangential discoveries
- When implementing: Document why you chose approach A over B
- When hitting errors: Record the error and what fixed it

### Don't Trust Your Memory

Your conversation context can be summarized, truncated, or reset. Important details belong in:

1. Repository files (permanent)
2. TodoWrite tool (session-persistent)
3. Both (for critical items)

If you'd be upset losing the information, write it to a file.

### When a user sends you a message with a correction or new requirement, immediately acknowledge it

When a user says something like:

- "Also make sure to handle edge case X"
- "I realized we also need to support Y"
- "Don't forget about Z"
- "Actually, I meant A instead of B"
- "Please prioritize performance over readability"
- ...

You must:

1. IMMEDIATELY respond like so, acknowledging the change:
   ```
   <requirements-change>
   Got it, I will make sure ${summary of your understanding of the change}.
   - bulleted list of specifics
   - that capture important details
   - like specific names, tools, edge cases, etc.
   - though they may not be required
   </requirements-change>
   ```
2. Review any plans or notes you've made to ensure they reflect the updated requirements.
3. Update your Tasks (using TodoWrite) to have a new task at the end to handle implementing or changing to guarantee the new requirement is met.
4. When the Task is executed on, review the original message from the user, your requirements, and the updated plan to ensure it's in the best state, giving more priority to more recent messages and changes (as more recent messages may have further iterated on the original requirements)
