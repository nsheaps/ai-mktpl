# Self-Terminate Plugin

A Claude Code plugin that enables Claude to gracefully terminate its own session.

Works for both local CLI sessions and Claude Code Web (remote sessions).

## Installation

This plugin is part of the nsheaps/.ai plugin collection. Install via:

```bash
claude plugins install github:nsheaps/.ai/plugins/self-terminate
```

Or add to `~/.claude/settings.json` for auto-installation:

```json
{
  "plugins": {
    "autoInstall": ["github:nsheaps/.ai/plugins/self-terminate"]
  }
}
```

## Usage

### Via Script (Recommended)

Claude can simply execute the provided script:

```bash
~/.claude/plugins/self-terminate/bin/self-terminate.sh
```

### Via Skill

The skill provides detailed instructions for manual termination if needed.

## How It Works

Claude Code runs as a process that spawns subshells for Bash commands. The script:

1. Identifies the parent process (Claude) via `$PPID`
2. Verifies it's actually a Claude process
3. Sends `SIGINT` for graceful termination

## Why SIGINT?

- **SIGINT (2)**: Graceful interrupt, allows cleanup
- **SIGTERM (15)**: Also graceful, but SIGINT is more conventional for user-initiated stops
- **SIGKILL (9)**: Force kill, no cleanup - avoid unless necessary

## Claude Code Web Compatibility

This plugin works seamlessly in Claude Code Web (remote sessions):

- Automatically handles the containerized environment
- Respects stop hooks that validate git state
- Script traverses the full process tree (process_api → environment-manager → claude)
- Alternative methods available: idle timeout, close browser tab

For Claude Code Web sessions, stop hooks may prevent termination if:

- There are uncommitted changes
- There are unpushed commits
- There are untracked files

Ensure clean git state before terminating to avoid hook blocking.

## Files

- `bin/self-terminate.sh` - Executable script for termination
- `skills/self-terminate/SKILL.md` - Detailed skill documentation

## License

MIT
