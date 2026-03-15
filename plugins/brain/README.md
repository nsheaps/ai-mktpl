# Brain Plugin

Git-backed memory, prompt tracking, self-checking reminders, and learning from failures.

## Features

### Prompt History Tracking

Every user prompt is automatically saved to `~/.claude/history.jsonl` on submit. Each entry includes timestamp, session ID, project directory, and the full prompt text.

On each prompt submit, the hook prints a system reminder encouraging the agent to validate its work against the original request — implementing the "Ralph loop" self-checking pattern from Serena MCP.

### Failure Triage & Learning (PostToolUseFailure)

When a tool fails, the brain plugin emits a system-reminder that instructs the agent to triage the failure:

1. **Haiku triage**: A fast haiku agent determines if the failure is learnable
2. **Background coaching**: If learnable, a background opus agent analyzes what went wrong and suggests skill/rule updates to prevent recurrence
3. **Correct-behavior integration**: The coaching agent references the `/correct-behavior` command pattern for structuring fixes

**Learnable failures**: tests you expected to pass, regressions, repeated tool usage mistakes, build failures from your code, API misunderstandings.

**Not learnable**: TDD test-before-implementation, user-denied permissions, network failures, intentional destructive testing.

### Behavior Skill Awareness (UserPromptSubmit)

On each prompt, the plugin checks if the `correct-behavior` plugin is installed and surfaces a reminder that `/correct-behavior` is available for formalizing behavioral fixes.

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

### UserPromptSubmit Hooks

1. **save-prompt.sh**: Reads the prompt from hook input, appends a JSON entry to `~/.claude/history.jsonl`, prints a self-check system-reminder
2. **load-behavior-skill.sh**: Checks if `correct-behavior` plugin is installed and surfaces a reminder that `/correct-behavior` is available

### SessionStart / TaskCompleted Hook

1. Checks if `gitRepo` is configured
2. Pulls latest from the memory repo
3. Copies configured memory sources into `memory/` directory in the repo
4. Commits and pushes if changes were made

### PostToolUseFailure Hook

1. **triage-failure.sh**: On any tool failure, emits a system-reminder instructing the agent to:
   - Use a haiku subagent to triage whether the failure is learnable
   - If learnable, launch a background opus agent to analyze and suggest skill/rule updates
   - Reference the `/correct-behavior` command for formalizing the fix

## Related Plugins

- **correct-behavior**: Provides the `/correct-behavior` command for formalizing behavioral corrections into rules/skills
- **time-context**: Temporal context investigation (previously part of this plugin, now standalone)
- **memory-manager**: Detects user preferences and writes them to `CLAUDE.md`; brain syncs those files to git

## Known Limitations

- `history.jsonl` grows without bound. For heavy usage, consider periodically truncating it manually. A future `maxHistoryEntries` setting is planned.

## Requirements

- `jq` (for JSON processing in hook scripts)
- `git` (for memory sync)
- Shared library: `plugin-config-read.sh`
