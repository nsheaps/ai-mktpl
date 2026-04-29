# Agentic Behavior Plugin

Skills for configuring Claude Code, behavior correction, memory tracking, autonomy rules, and time-context awareness.

## Skills

### /correct-behavior

Corrects AI behavior mistakes and updates rules to prevent recurrence. Auto-triggered by Claude when it detects corrective feedback, or invoke explicitly as `/agentic-behavior:correct-behavior [SCOPE] <description>` (see `skills/correct-behavior/SKILL.md`).

### /time-context

Detects time-referencing language in prompts and investigates history before answering (see `skills/time-context/SKILL.md`).

### /brain

Git-backed memory and prompt tracking with self-checking reminders (see `skills/brain/SKILL.md`).

### /issue-management (moved to sdlc-utils)

Issue management is an SDLC concern. This skill now lives in the `sdlc-utils` plugin.

### /spec-management

Manage specification documents co-located with plugins. Covers the spec lifecycle (draft through archive), combined format with Given/When/Then acceptance criteria, and the rule that every plugin change PR must include a spec update (see `skills/spec-management/SKILL.md`). Includes a starter template at `skills/spec-management/references/spec-template.md`.

### /incident-tracker

Track behavioral incidents with structured incident files (severity, tags, status), derive reusable rules, and maintain footnote references between rules and source incidents. Auto-discovers the workspace rules file (CLAUDE.md, AGENTS.md, or a configured override) so rules land in the right place. Complementary to `correct-behavior` -- use `incident-tracker` when the goal is producing a durable audit trail of *what happened*, and `correct-behavior` for active fixes (see `skills/incident-tracker/SKILL.md`).

### /exit

Gracefully exit the Claude Code session by sending SIGINT to the Claude process. Includes git state validation to prevent exiting with uncommitted or unpushed work (see `skills/exit/SKILL.md`).

### /restart

Restart the Claude Code session by gracefully exiting so the launcher loop restarts it. Use when you need to pick up config changes, plugin updates, or env var changes (see `skills/restart/SKILL.md`).

## Rules

### autonomy.md

Rules for autonomous decision-making, recommendation style, merge approval, and research-first patterns. Synced into project `.claude/rules/` via the SessionStart hook.

### work-tracking.md

Platform-agnostic rules for how tasks, PRs, and milestones relate to each other. Covers linking requirements (work items to milestones, PRs to work items), status tracking, and milestone management. Concrete implementations (GitHub Issues, Linear, etc.) are provided by separate skills in appropriate plugins.

## Features

### Prompt History Tracking

Every user prompt is automatically saved to `~/.claude/history.jsonl` on submit. Each entry includes timestamp, session ID, project directory, and the full prompt text.

On each prompt submit, the hook prints a system reminder encouraging the agent to validate its work against the original request — implementing the "Ralph loop" self-checking pattern from Serena MCP.

### Git-Backed Memory Sync

Configure a git repository to automatically version-control your memory files (CLAUDE.md, history, etc.). Memory syncs happen on:

- **Session start**: Pull latest from remote
- **Task completion**: Commit and push changes

### Rules Sync

On session start, creates a symlink at `.claude/rules/agentic-behavior` pointing to this plugin's `rules/` directory, making autonomy and other rules available as Claude Code context.

### Self-Validation (Ralph Loop)

Inspired by the Serena MCP "is task done" command, the plugin encourages a discipline of:

1. Saving the original prompt
2. Reminding the agent to check work against the prompt while working
3. Explicit self-check before declaring a task done

## Relationship with memory-manager

The `memory-manager` plugin detects user preferences during a session and writes them to `CLAUDE.md`. The `agentic-behavior` plugin is complementary — it syncs those files (and prompt history) to a separate git repo for version-controlled persistence across sessions. You can use both together: `memory-manager` writes the memories, `agentic-behavior` backs them up.

## Configuration

Add to `~/.claude/plugins.settings.yaml` or project-level `.claude/plugins.settings.yaml`:

```yaml
agentic-behavior:
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

### SessionStart Hook

1. Creates a symlink at `.claude/rules/agentic-behavior` for rule delivery
2. Checks if `gitRepo` is configured
3. Pulls latest from the memory repo if configured
4. Copies configured memory sources into `memory/` directory in the repo
5. Commits and pushes if changes were made

### TaskCompleted Hook

1. Checks if `gitRepo` is configured
2. Copies updated memory files into the memory repo
3. Commits and pushes if changes were made

## Known Limitations

- `history.jsonl` grows without bound. For heavy usage, consider periodically truncating it manually. A future `maxHistoryEntries` setting is planned.

## Requirements

- `jq` (for JSON processing in hook scripts)
- `git` (for memory sync)
- Shared library: `hook-logging.sh`, `plugin-config-read.sh`
