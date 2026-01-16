---
name: self-terminate
description: |
  Gracefully terminate the Claude Code session by sending SIGINT to the Claude process.
  Works for local CLI sessions and Claude Code Web (remote sessions).
  Use when you make a change that requires a restart, or when the user requests termination.
---

# Self-Terminate Skill

This skill enables Claude to gracefully terminate its own session by sending a SIGINT signal to its process.

## When to Use This Skill

- When the user explicitly asks Claude to exit or terminate
- When Claude needs to restart with a fresh session (e.g., after configuration changes)
- When running Claude Code Web and you make a change that requires a session restart
- When testing process management or signal handling

## Automatic Git State Validation

This plugin includes a PreToolUse hook that automatically validates git state before termination:

✅ **Automatically checks:**
1. No uncommitted changes (staged or unstaged)
2. No unpushed commits
3. No untracked files

❌ **Blocks termination if:**
- Working directory is dirty
- Commits haven't been pushed
- Untracked files exist

The hook provides clear error messages explaining what needs to be resolved before termination can proceed.

## How It Works

Claude runs as a process that spawns shell subprocesses for Bash commands. The parent PID (`$PPID`) of any spawned shell is the Claude process itself.

Sending `SIGINT` (signal 2) to the Claude process triggers a graceful shutdown, similar to pressing `Ctrl+C`.

## Quick Method: Use the Script

The easiest way is to execute the provided script:

```bash
/path/to/plugins/self-terminate/bin/self-terminate.sh
```

Or if the plugin is installed:

```bash
~/.claude/plugins/self-terminate/bin/self-terminate.sh
```

## Manual Method

If the script is unavailable, Claude can terminate itself manually:

### Step 1: Identify the Claude Process

```bash
echo "Shell PID: $$"
echo "Claude PID (parent): $PPID"
ps -o pid,ppid,comm -p $$ -p $PPID
```

### Step 2: Verify It's Claude

```bash
ps -o comm= -p $PPID
```

This should output `claude` or similar.

### Step 3: Send SIGINT

```bash
kill -INT $PPID
```

## Process Tree Context

A typical Claude Code process tree looks like:

```
iTerm/Terminal
└── shell (user's interactive shell)
    └── claude (PID: XXXXX)  ← Target this
        └── /bin/zsh (spawned for Bash commands)
            └── (your command)
```

## Safety Notes

- **SIGINT** causes graceful termination - Claude can clean up
- **SIGTERM** also works for graceful shutdown
- **SIGKILL** (-9) should be avoided - no cleanup opportunity
- The script verifies the parent is actually Claude before sending the signal

## What Happens After

After termination:

1. The Claude session ends immediately
2. Any in-progress work is interrupted
3. The user returns to their shell
4. A new session can be started with `claude`

## Troubleshooting

**Script says parent is not Claude**: You may be running in a nested shell or different environment. Check `pstree -p $$` to see the full process tree.

**Signal ignored**: Some environments may mask signals. Try `kill -TERM $PPID` as an alternative.

## Stop Hooks (Claude Code Web)

In Claude Code Web environments, stop hooks may validate state before shutdown:

- Checks for uncommitted changes
- Checks for untracked files
- Checks for unpushed commits
- Blocks shutdown (exit 2) if validation fails
- Allows shutdown (exit 0) if clean

Example stop hook location: `~/.claude/stop-hook-git-check.sh`

## Environment Detection

| Environment Variable     | Purpose                              |
| ------------------------ | ------------------------------------ |
| `CLAUDE_CODE_REMOTE`     | Set to "true" in Claude Code Web     |
| `CLAUDE_PROJECT_DIR`     | Repository root (available in hooks) |
| `CLAUDE_CODE_SESSION_ID` | Current session UUID                 |

## Alternative Methods (Claude Code Web Only)

For Claude Code Web sessions, you can also terminate by:

1. **Idle timeout** - Stop sending messages and wait for auto-shutdown
2. **Close browser tab** - Session terminates gracefully
3. **UI controls** - Use session management UI if available
