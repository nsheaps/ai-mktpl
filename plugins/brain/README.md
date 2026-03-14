# Brain Plugin

Git-backed memory and prompt tracking with self-checking reminders.

## Features

### Prompt History Tracking

Every user prompt is automatically saved to `~/.claude/history.jsonl` on submit. Each entry includes timestamp, session ID, project directory, and the full prompt text.

On each prompt submit, the hook prints a system reminder encouraging the agent to validate its work against the original request — implementing the "Ralph loop" self-checking pattern from Serena MCP.

### Git-Backed Memory Sync

Configure a git repository to automatically version-control your memory files (CLAUDE.md, history, etc.). Memory syncs happen on:

- **Session start**: Pull latest from remote
- **Task completion**: Commit and push changes

### Self-Validation (Ralph Loop)

Inspired by the Serena MCP "is task done" command, the plugin encourages a discipline of:

1. Saving the original prompt
2. Reminding the agent to check work against the prompt while working
3. Explicit self-check before declaring a task done

## Relationship with memory-manager

The `memory-manager` plugin detects user preferences during a session and writes them to `CLAUDE.md`. The `brain` plugin is complementary — it syncs those files (and prompt history) to a separate git repo for version-controlled persistence across sessions. You can use both together: `memory-manager` writes the memories, `brain` backs them up.

## Configuration

Add to `~/.claude/plugins.settings.yaml` or project-level `.claude/plugins.settings.yaml`:

```yaml
brain:
  enabled: true
  gitRepo: "~/path/to/memory-repo"
  gitBranch: "main"
  selfCheckReminder: "always"
  memorySources:
    - "~/.claude/CLAUDE.md"
    - "~/.claude/history.jsonl"
```

### Settings

| Key                 | Default     | Description                                                                                 |
| ------------------- | ----------- | ------------------------------------------------------------------------------------------- |
| `enabled`           | `true`      | Enable/disable the plugin                                                                   |
| `gitRepo`           | `""`        | Path to git repo for memory storage (empty = disabled)                                      |
| `gitBranch`         | `"main"`    | Branch to use for memory commits                                                            |
| `selfCheckReminder` | `"always"`  | When to show the self-check reminder: `"always"`, `"first"` (once per session), or `"none"` |
| `memorySources`     | (see below) | Files to sync to the memory repo                                                            |

**Default memory sources** (when `memorySources` is not set):

- `~/.claude/CLAUDE.md`
- `~/.claude/history.jsonl`
- Project `CLAUDE.md` (if present)

## How It Works

### UserPromptSubmit Hook

1. Reads the prompt from hook input
2. Appends a JSON entry to `~/.claude/history.jsonl`
3. Prints a system-reminder to stderr for the agent

### SessionStart / TaskCompleted Hook

1. Checks if `gitRepo` is configured
2. Pulls latest from the memory repo
3. Copies configured memory sources into `memory/` directory in the repo
4. Commits and pushes if changes were made

## Known Limitations

- `history.jsonl` grows without bound. For heavy usage, consider periodically truncating it manually. A future `maxHistoryEntries` setting is planned.

## Requirements

- `jq` (for JSON processing in hook scripts)
- `git` (for memory sync)
- Shared library: `plugin-config-read.sh`
