---
name: restart
description: |
  Restart the Claude Code session by gracefully exiting so the launcher loop restarts it.
  Use when you need to pick up config changes, plugin updates, or env var changes.
  Requires a launcher script (e.g., run-agent.sh) that restarts Claude after exit.
---

# Restart

This skill enables Claude to restart its own session by performing a graceful exit (SIGINT), relying on the launcher script to restart the process.

## When to Use This Skill

- After making configuration changes that require a restart (plugin updates, settings changes)
- After environment variable changes that only take effect on session start
- When the handler requests a restart
- When you need a fresh session to pick up new hooks or rules

## How It Works

Restart is simply an exit with the expectation that a launcher script will restart Claude:

1. **Validate git state** -- same checks as `/exit` (no uncommitted changes, no unpushed commits)
2. **Save continuation state** -- optionally write a continuation prompt so the restarted session picks up where you left off
3. **Send SIGINT** -- gracefully exit the session
4. **Launcher restarts** -- the wrapper script (e.g., `run-agent.sh`) detects the exit and starts a new Claude session

## Prerequisites

- A launcher script that restarts Claude after exit (e.g., a `while true` loop)
- If no launcher is present, restart behaves identically to exit -- the session simply ends

## Quick Method

Use the exit script -- restart is just exit with launcher support:

```bash
${CLAUDE_PLUGIN_ROOT}/bin/exit.sh
```

## Saving Continuation State

Before restarting, you may want to save state so the new session can resume:

1. Write a continuation prompt to `.claude/tmp/continuation-prompt.md`
2. Update `.claude/scratch/tasks.md` with current progress
3. Commit any in-progress work

The launcher script or SessionStart hook can then read the continuation prompt on startup.

## Difference from Exit

| Aspect             | `/exit`         | `/restart`               |
| ------------------ | --------------- | ------------------------ |
| Intent             | End the session | Restart with fresh state |
| Mechanism          | SIGINT          | SIGINT (same)            |
| Launcher behavior  | Session ends    | Launcher restarts Claude |
| State preservation | Not expected    | Save continuation prompt |
| Git validation     | Required        | Required                 |

## See Also

- `/exit` -- graceful session exit without restart
- `self-restart` skill in the project repo -- may contain project-specific restart procedures
