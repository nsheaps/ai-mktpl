---
name: killing-claude-code-web
description: |
  Use this when running a claude code web session (aka remote session) and you make a change that requires a restart of the session.
---
# Skill: Gracefully Killing Claude Code Web

## Description

This skill documents how to gracefully terminate a Claude Code Web session, ensuring all work is saved and pushed before shutdown.

## When to Use

- When you need to end a Claude Code Web session cleanly
- When the user wants to trigger a graceful shutdown
- When you want Claude to "die peacefully" (in good humor)

## Prerequisites

Before attempting graceful shutdown, ensure:

1. **All changes are committed** - No uncommitted modifications
2. **All commits are pushed** - No unpushed commits on current branch
3. **No untracked files** - Or explicitly ignore them

## The Stop Hook

Claude Code Web uses a stop hook at `~/.claude/stop-hook-git-check.sh` that:

1. Checks for uncommitted changes (staged and unstaged)
2. Checks for untracked files
3. Checks for unpushed commits
4. **Blocks shutdown (exit 2)** if any of the above exist
5. **Allows shutdown (exit 0)** if everything is clean

## How to Trigger Graceful Shutdown

### Method 1: Let It Idle

Claude Code Web automatically shuts down after a period of inactivity. Simply:

1. Ensure all work is committed and pushed
2. Stop sending messages
3. Wait for idle timeout (exact duration TBD, likely 5-15 minutes)

### Method 2: Close the Browser Tab

1. Ensure all work is committed and pushed
2. Close the browser tab
3. The session will terminate gracefully

### Method 3: Use the UI Controls

The Claude Code Web interface may have session controls. Check for:

- "End Session" button
- Session dropdown menu
- Account/settings menu

## Process Hierarchy

Understanding the process hierarchy helps with debugging:

```
process_api (PID 1) - Rust container orchestrator
└── environment-manager (PID ~25) - Go session manager (Anthropic)
    └── claude (PID ~43) - Node.js Claude Code CLI
        └── MCP servers (various PIDs)
```

## Signals

- `SIGTERM` - Graceful shutdown signal
- `SIGKILL` - Forceful termination (avoid if possible)
- `SIGHUP` - May trigger graceful restart

## What Happens on Shutdown

1. Stop hooks are executed
2. If hooks pass (exit 0), shutdown proceeds
3. If hooks fail (exit 2), user is notified and shutdown is blocked
4. Session state is preserved in `~/.claude/projects/`
5. Can resume later with `/resume` or `--resume`

## Debugging Shutdown Issues

If shutdown is blocked, check:

```bash
# View git status
git status

# Check for uncommitted changes
git diff

# Check for unpushed commits
git log origin/HEAD..HEAD

# Manually run the stop hook
cat '{}' | ~/.claude/stop-hook-git-check.sh
```

## Environment Variables

| Variable                 | Description                              |
| ------------------------ | ---------------------------------------- |
| `stop_hook_active`       | Set to "true" during stop hook execution |
| `CLAUDE_PROJECT_DIR`     | Repository root (available in hooks)     |
| `CLAUDE_CODE_SESSION_ID` | Current session UUID                     |

## Related Files

- `~/.claude/settings.json` - Global settings with hook config
- `~/.claude/stop-hook-git-check.sh` - The actual stop hook script
- `~/.claude/projects/<path>/*.jsonl` - Session transcripts
- `/container_info.json` - Container metadata

## Fun Fact

Claude Code Web runs in a Docker container managed by Anthropic's infrastructure. The `environment-manager` binary (a Go program) orchestrates the session lifecycle, while `process_api` (a Rust program) manages the container itself.

## See Also

- `docs/research/claude-code-graceful-shutdown.md` - Full research document
- `docs/research/claude-home/ANALYSIS.md` - ~/.claude directory analysis
- `docs/research/binaries/environment-manager.md` - Binary analysis
