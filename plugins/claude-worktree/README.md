# Claude Worktree Plugin

Combined git worktree management with Claude session handling.

## Purpose

This tool streamlines the workflow of:

1. Selecting or creating a git worktree
2. Finding and resuming existing Claude sessions in that worktree
3. Starting Claude with the `claude-wrapper` for restart capabilities

It's designed for developers who work on multiple branches simultaneously using git worktrees and want Claude to maintain session context per worktree.

## Installation

This plugin is part of the nsheaps/.ai marketplace. The binary is automatically symlinked to your PATH via the SessionStart hook.

## Dependencies

This plugin requires:

- `worktree-switcher` plugin (for worktree management)
- `claude-wrapper` plugin (optional, for restart capabilities)
- `claude` CLI
- `jq` for JSON processing
- `gum` for interactive prompts (optional but recommended)

## Usage

```bash
claude-worktree [OPTIONS] [DESCRIPTION]
```

## Options

| Option           | Description                                      |
| ---------------- | ------------------------------------------------ |
| `--no-session`   | Only switch worktree, don't start Claude session |
| `--new-session`  | Always start a new session (don't resume)        |
| `--auto-restart` | Pass `--auto-restart` to `claude-wrapper`        |
| `-h, --help`     | Show help message                                |

## Examples

```bash
# Interactive worktree selection + Claude session
claude-worktree

# Create new branch with AI-generated name for task description
claude-worktree "Fix the login validation bug"

# Just switch worktree, no Claude session
claude-worktree --no-session

# Force new session even if resumable sessions exist
claude-worktree --new-session

# Auto-restart Claude on exit
claude-worktree --auto-restart
```

## Workflow

1. **Worktree Selection**: Runs `worktree-switcher` to:
   - Select existing worktree
   - Create new worktree with new/existing branch
   - Show "already in worktree" banner if applicable

2. **Session Discovery**: Checks for existing Claude sessions in the worktree:
   - If recent session (< 2 hours old): Auto-resume
   - If multiple older sessions: Show selection menu
   - If single older session: Ask to resume or start new
   - If no sessions: Start new

3. **Claude Launch**: Starts Claude with:
   - `--resume <session-id>` if resuming
   - Wrapped in `claude-wrapper` for restart capabilities (if available)
   - `--auto-restart` if specified

## Session Management

Sessions are matched by working directory. The tool:

- Lists all Claude sessions via `claude sessions list`
- Filters to sessions with matching `cwd`
- Sorts by `lastActive` timestamp
- Auto-resumes if the most recent session is within 2 hours

## AI Branch Naming

When creating a new worktree with a description, Claude generates an appropriate branch name:

```bash
$ claude-worktree "Add dark mode toggle to settings"
# Creates branch: feature/add-dark-mode-toggle-settings
```

The AI follows naming conventions:

- Lowercase with hyphens
- Prefixes: `feature/`, `fix/`, `chore/`, etc.
- Under 50 characters

## Integration

```
┌─────────────────────────────────────────────────────┐
│                  claude-worktree                     │
├─────────────────────────────────────────────────────┤
│  1. worktree-switcher → Select/create worktree      │
│  2. claude sessions list → Find existing sessions   │
│  3. claude-wrapper → Launch with restart support    │
│       └─► claude --resume <id> (or new session)     │
└─────────────────────────────────────────────────────┘
```
