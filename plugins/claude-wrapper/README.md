# Claude Wrapper Plugin

A process supervisor for the interactive Claude CLI with restart capabilities.

## Purpose

This tool is designed for **end users running `claude` interactively**. It monitors the Claude process and offers restart options when it exits, which is useful for:

- Long-running interactive sessions
- Auto-recovery from crashes
- tmux/screen sessions where you want persistence

**Note:** This wrapper is NOT needed for `claude-simple-cli` since that runs in one-shot mode (each prompt is a new session).

## Installation

This plugin is part of the nsheaps/.ai marketplace. The binary is automatically symlinked to your PATH via the SessionStart hook.

## Usage

```bash
claude-wrapper [OPTIONS] [-- COMMAND [ARGS...]]
```

## Options

| Option           | Description                                             |
| ---------------- | ------------------------------------------------------- |
| `--no-restart`   | Exit immediately when child exits (don't offer restart) |
| `--auto-restart` | Automatically restart on non-zero exit (no prompt)      |
| `-h, --help`     | Show help message                                       |

## Examples

```bash
# Run interactive claude with restart prompts
claude-wrapper

# Run claude with specific model
claude-wrapper -- claude --model opus

# Auto-restart on crash (useful for unattended sessions)
claude-wrapper --auto-restart

# Run once without restart option
claude-wrapper --no-restart

# Use with tmux
tmux new-session -d -s claude 'claude-wrapper --auto-restart'
```

## Features

### Binary Detection

The wrapper automatically finds the actual `claude` binary, bypassing shell functions or aliases. It checks:

1. `/usr/local/bin/claude`
2. `/opt/homebrew/bin/claude`
3. `~/.local/bin/claude`
4. `~/.npm/bin/claude`
5. `~/.bun/bin/claude`
6. `which claude` fallback

### Signal Handling

- Forwards SIGINT (Ctrl+C) and SIGTERM to the child process
- Waits for clean termination before exiting
- Exit code 130 on interrupt

### Restart Options

When the Claude process exits:

1. **Interactive mode** (default): Prompts to restart or quit
2. **Auto-restart mode** (`--auto-restart`): Automatically restarts on non-zero exit
3. **No-restart mode** (`--no-restart`): Exits immediately with child's exit code

## Exit Codes

| Code  | Meaning                        |
| ----- | ------------------------------ |
| 0     | Clean exit                     |
| 130   | User interrupt (Ctrl+C)        |
| Other | Exit code from wrapped command |

## Integration

This wrapper is used by `claude-worktree` to provide persistent Claude sessions within git worktrees.
