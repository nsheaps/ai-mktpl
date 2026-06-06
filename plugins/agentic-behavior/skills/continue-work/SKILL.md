---
name: continue-work
description: >-
  Session recovery skill. Use on startup, after compaction, or when resuming
  work after any interruption. Restores crons, audits recent history to
  determine current state, and identifies what to work on next.
allowed-tools: Read, Glob, Grep, Bash(git log:*), Bash(git status:*), Bash(ls:*), CronCreate, CronList, CronDelete, TaskCreate, TaskUpdate, TaskList, Agent
---

# Continue Work

Recover session state and resume work after a restart, compaction, or interruption.

## When to Use

- On session startup (when no CONTINUATION.md exists)
- After auto-compaction (cron state may be lost)
- When you've lost track of what you were doing
- When the handler asks "where were you?" or "what's the status?"

## Steps

### 1. Restore Scheduled Tasks (MANDATORY)

Read `.claude/scheduled-tasks.yaml` and recreate ALL enabled crons:

```
1. Read .claude/scheduled-tasks.yaml
2. For each task where enabled: true:
   - Call CronCreate with the task's cron expression and prompt
   - Use recurring: true for recurring tasks, false for one-shot
3. Verify with CronList that all expected crons are active
4. Catch-up check (see staleness rules below)
```

#### Catch-Up Staleness Rules

When a session was down and crons were missed, apply these rules to decide
whether to fire a catch-up run:

- **Recurring crons:** Fire **once** (not N times) if the most recent missed
  firing was within **2x the cron interval** (e.g., a 15-minute cron catches up
  if the session was down less than 30 minutes). Beyond that window, skip the
  catch-up and wait for the next scheduled firing.
- **One-shot crons:** Catch up only if the scheduled time was within the
  **last 24 hours**. Older one-shots are considered stale -- log them as missed
  rather than firing.
- **Daily tasks** (morning briefing, lessons, etc.): Catch up only if today's
  scheduled time has already passed and the task has not yet run today.
- **Never replay a backlog:** The goal is "make sure the most recent run
  happened," not "replay every missed interval." One catch-up firing per cron
  is the maximum.

**CRITICAL:** CronCreate state is session-only. It does NOT survive compaction
or restart. You MUST recreate crons from the YAML file every time this skill
runs — even if you think they might still be active. Check with CronList first
to avoid duplicates.

### 2. Audit Recent Activity

Determine what you were working on by checking these sources in order:

1. **TaskList** — check for in_progress tasks (fastest signal)
2. **Git status** — any uncommitted changes? What branch?
3. **Git log** — recent commits (last 5-10) to see what was just done
4. **Communication channels** — check active work threads or channels for recent messages
5. **`.claude/tmp/`** — any intermediate work files?
6. **Recent transcript** — if available, check the last few messages for context

### 3. Assess State

For each piece of active work found, determine:

- **What was being done** — the specific task or PR
- **What's complete** — commits pushed, reviews posted, issues updated
- **What's next** — the logical next step
- **What's blocked** — anything waiting on handler, CI, or another agent

### 4. Report & Resume

Post a brief status summary (to the handler's active channel, or terminal):

```
Session recovered. State:
- Restored N crons from scheduled-tasks.yaml
- Active work: [brief description]
- Next step: [what you'll do now]
- Blocked: [anything waiting on someone]
```

Then continue working on the highest-priority active item.

## What NOT to Do

- Don't assume you know what you were doing — verify from artifacts
- Don't skip cron restoration because "they might still be active"
- Don't start new work without checking for in-progress items first
- Don't report completion without checking TaskList for open tasks

## References

- Cron persistence rules live in the agent's project repo (`.claude/rules/scheduled-tasks.md`), not in this plugin
- `rules/autonomy.md` — when to act vs when to ask
- Investigation: Henry lost 15m cron across 24 compactions because cron
  restoration was never triggered after compaction (2026-04-25)
