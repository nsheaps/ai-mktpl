# Claude Tools Plugin

> [!WARNING]
> **DISTRIBUTION MECHANISM NEEDS MIGRATION**
>
> The current symlink-based distribution via SessionStart hooks is a temporary solution.
> These tools should be distributed through a proper package manager:
>
> - **Homebrew** (`brew install claude-tools`)
> - **npm** (`npm install -g @nsheaps/claude-tools`)
> - **mise** (`.mise.toml` with custom plugin)
>
> This would provide proper versioning, updates, and cross-platform support.
> See issue tracking this migration or create one if it doesn't exist.

A collection of CLI tools for Claude Code workflow management including diagnostics, worktree management, session handling, and process supervision.

## Installation

This plugin is part of the nsheaps/.ai marketplace. The binaries are automatically symlinked to your PATH via the SessionStart hook.

## Binaries

### claude-diagnostics

Diagnostic tool that captures Claude Code status, context, and configuration files for troubleshooting.

```bash
claude-diagnostics [OPTIONS]
```

**Options:**

| Option          | Description                                            |
| --------------- | ------------------------------------------------------ |
| `-v, --verbose` | Print diagnostics to console (quiet by default)        |
| `--no-archive`  | Only print diagnostics to stdout, don't create archive |
| `--no-user`     | Exclude user-level config (~/.claude/, ~/.ai/)         |
| `--no-project`  | Exclude project-level config (.claude/, .ai/)          |
| `--no-rules`    | Exclude rules files                                    |
| `--no-agents`   | Exclude agent definitions                              |
| `--no-commands` | Exclude command/skill files                            |
| `--no-settings` | Exclude settings.json files                            |
| `-h, --help`    | Show help message                                      |

**Output:** Creates a `.tar.gz` archive in `/tmp/` containing diagnostics.md, init.json, and config files.

### claude-simple-cli

Simplified one-shot text-based interface over Claude's JSON mode. Suitable for scripts, piping, and quick queries.

```bash
claude-simple-cli [OPTIONS] [PROMPT]
```

**Options:**

| Option            | Description                                       |
| ----------------- | ------------------------------------------------- |
| `--resume <id>`   | Resume a previous session by ID                   |
| `--fork-session`  | Fork from resumed session (don't modify original) |
| `--json`          | Output raw JSON response (default: text)          |
| `--no-stream`     | Wait for complete response                        |
| `--model <model>` | Use specific model (opus, sonnet, haiku)          |
| `-p, --print`     | Print mode (suppress session ID hint)             |
| `-h, --help`      | Show help message                                 |

**Examples:**

```bash
claude-simple-cli "What is the capital of France?"
cat error.log | claude-simple-cli "Explain this error"
claude-simple-cli --resume abc123 "Can you elaborate on that?"
```

### claude-wrapper

Process supervisor for the interactive Claude CLI with restart capabilities. Useful for long-running interactive sessions, auto-recovery from crashes, and tmux/screen sessions.

```bash
claude-wrapper [OPTIONS] [-- COMMAND [ARGS...]]
```

**Options:**

| Option           | Description                                             |
| ---------------- | ------------------------------------------------------- |
| `--no-restart`   | Exit immediately when child exits (don't offer restart) |
| `--auto-restart` | Automatically restart on non-zero exit (no prompt)      |
| `-h, --help`     | Show help message                                       |

**Examples:**

```bash
claude-wrapper                          # Run interactive claude with restart prompts
claude-wrapper -- claude --model opus   # Run claude with specific model
claude-wrapper --auto-restart           # Auto-restart on crash
tmux new-session -d -s claude 'claude-wrapper --auto-restart'
```

### claude-worktree

Combined git worktree management with Claude session handling. Streamlines the workflow of selecting worktrees and resuming Claude sessions.

```bash
claude-worktree [OPTIONS] [DESCRIPTION]
```

**Options:**

| Option           | Description                                      |
| ---------------- | ------------------------------------------------ |
| `--no-session`   | Only switch worktree, don't start Claude session |
| `--new-session`  | Always start a new session (don't resume)        |
| `--auto-restart` | Pass `--auto-restart` to `claude-wrapper`        |
| `-h, --help`     | Show help message                                |

**Examples:**

```bash
claude-worktree                          # Interactive worktree + session
claude-worktree "Fix login bug"          # AI-named branch for this task
claude-worktree --no-session             # Just switch worktree
```

**Features:**

- Auto-resumes sessions from the same worktree (< 2 hours old)
- AI-generated branch names from task descriptions
- Integrates with `worktree-switcher` and `claude-wrapper`

### worktree-switcher

Interactive TUI for git worktree management with rich branch status display.

```bash
worktree-switcher [OPTIONS] [BRANCH]
```

**Arguments:**

| Argument | Description                                                    |
| -------- | -------------------------------------------------------------- |
| `BRANCH` | Branch name to create/switch to worktree for (skips selection) |

**Options:**

| Option           | Description                                      |
| ---------------- | ------------------------------------------------ |
| `--no-status`    | Skip fetching branch status (faster)             |
| `--scan-dir DIR` | Directory to scan for git repos (default: ~/src) |
| `--repo REPO`    | GitHub repo (owner/name) to clone if not in repo |
| `-h, --help`     | Show help message                                |

**Examples:**

```bash
# Interactive mode - select and switch to worktree (launches new shell)
worktree-switcher

# Direct branch switch - find or create worktree for branch
worktree-switcher claude/fix-review-bot-ZQa8q

# Clone a repo and create worktree
worktree-switcher --repo nsheaps/.ai feature/my-branch

# Faster mode without status checks
worktree-switcher --no-status
```

**Features:**

- **Auto-switch**: After selection, launches a new shell in the worktree directory
- **Direct branch argument**: Pass a branch name to skip interactive selection
- **Smart branch detection**: Finds local, remote, or creates new branches
- **Repo discovery**: When not in a git repo, offers to:
  - Scan `~/src` (or custom dir) for existing repos
  - Clone from GitHub by selecting from org/user repos
  - Enter a path manually
- **"Switch repository" option**: Step up to change repos during selection
- Shows banner if already in a worktree
- Create new worktrees with new branches
- Select from existing worktrees
- Branch priority (your PRs > your branches > other branches)
- Worktrees created at: `../${repo}.worktrees/${branch}`

### branch-status

Utility to display rich status information for git branches.

```bash
branch-status [OPTIONS] <branch>
```

**Options:**

| Option       | Description                      |
| ------------ | -------------------------------- |
| `--emoji`    | Output as emoji string (default) |
| `--json`     | Output as JSON object            |
| `-h, --help` | Show help message                |

**Status Indicators (emoji mode):**

| Position | Indicator         | Meaning                                                             |
| -------- | ----------------- | ------------------------------------------------------------------- |
| 1        | 🟢/❌             | Remote: exists / doesn't exist                                      |
| 2        | 🟢/🔘/❓          | PR: open / draft / none                                             |
| 3        | ❌/🟡/🟢/❓       | CI: fail / running / pass / no CI                                   |
| 4        | ✅/🟢/🔴/🟡/🔵/🔘 | Review: satisfied / approved / rejected / comments / pending / none |
| 5        | ✅/❌/⚠️/🟢       | Merge: ready / conflicts / outdated / clean                         |

**Example:**

```bash
$ branch-status --emoji feature/my-branch
🟢🟢🟢🟢✅

$ branch-status --json feature/my-branch
{
  "branch": "feature/my-branch",
  "remote_exists": true,
  "pr_status": "open",
  "pr_number": 42,
  "ci_status": "pass",
  "review_status": "approved",
  "mergeable": "ready"
}
```

## Dependencies

| Tool     | Purpose             | Installation          |
| -------- | ------------------- | --------------------- |
| `gum`    | Interactive prompts | `brew install gum`    |
| `gh`     | GitHub CLI          | `brew install gh`     |
| `jq`     | JSON processing     | `brew install jq`     |
| `git`    | Version control     | Usually pre-installed |
| `claude` | Claude CLI          | Pre-installed         |

## Security Note

When using `claude-diagnostics`, always review the archive contents before sharing, as it may contain:

- API keys or tokens in settings files
- Personal paths and usernames
- Project-specific configuration

Use the exclusion options to filter sensitive data.
