---
name: self-terminate
description: Gracefully terminate the Claude Code session by sending SIGINT to the Claude process
---

# Self-Terminate Skill

This skill enables Claude to gracefully terminate its own session by sending a SIGINT signal to its process.

## When to Use This Skill

- When the user explicitly asks Claude to exit or terminate
- When Claude needs to restart with a fresh session
- When testing process management or signal handling

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
