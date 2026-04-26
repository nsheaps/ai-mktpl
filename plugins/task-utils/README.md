# task-utils

Unified task management plugin for Claude Code agents. Consolidates `todo-plus-plus`, `todo-sync`, and `task-parallelization` into a single cohesive plugin.

See the full spec at [`docs/spec.md`](docs/spec.md).

## Features

- **Commit-on-Complete** (`TaskCompleted` hook): Blocks task completion if there are uncommitted or unpushed changes
- **Session Awareness** (`SessionStart` hook): Reminds agents that Tasks are session-scoped and not persistent; to always commit before completing tasks
- **Active-Task Guard** (`PreToolUse` hook, advisory): Warns when a tool is used with no active task (scaffold — no-op in this release)
- **Stop Guard** (`Stop` hook, advisory): Warns when a session ends with in-progress tasks (scaffold — no-op in this release)
- **Provider-based Task Sync** (`PostToolUse:TaskCreate/TaskUpdate`): Syncs task state to configured backends (Filesystem, GitHub Issues) (scaffold — no-op in this release)
- **Task Parallelization skill**: Migrated from `task-parallelization` — guidance on running parallel sub-agents
- **Task Management skill**: New skill covering the full task lifecycle, naming conventions, and delegation patterns

## Installation

Add `task-utils` to your `enabledPlugins` in `settings.json`. Remove `todo-plus-plus`, `todo-sync`, and `task-parallelization` if previously installed.

## Configuration

> **Not yet implemented.** The configuration knobs below are planned for v1.1. In v0.1.0, all hooks use hardcoded defaults — `commitCheck` is always on, stub hooks always exit 0, and no provider sync runs. No `plugins.settings.yaml` is read.

```yaml
# plugins.settings.yaml (planned — not read in v0.1.0)
task-utils:
  providers:
    filesystem:
      enabled: true # writes task state to $CLAUDE_PROJECT_DIR/.claude/tasks/
    githubIssues:
      enabled: false # set true to enable GitHub issue sync
      repo: "owner/repo" # required if enabled: true
      labels:
        - "agent-task"
      closeOnComplete: true
  commitCheck:
    enabled: true # block TaskCompleted if uncommitted changes exist
  stopGuard:
    enabled: true # warn on Stop if in_progress tasks remain
  activeTaskGuard:
    enabled: true # warn on tool use if no active task
```

## File Structure

```
task-utils/
├── .claude-plugin/
│   └── plugin.json
├── docs/
│   └── spec.md                       # full specification
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       ├── check-uncommitted.sh      # TaskCompleted — commit guard
│       ├── session-start.sh          # SessionStart — awareness message
│       ├── active-task-guard.sh      # PreToolUse — active task advisory
│       ├── stop-guard.sh             # Stop — in-progress task advisory
│       ├── sync-task-create.sh       # PostToolUse:TaskCreate — provider sync
│       └── sync-task-update.sh       # PostToolUse:TaskUpdate — provider sync
├── lib/
│   └── log.sh                        # shared logging helpers
├── skills/
│   ├── task-parallelization/
│   │   └── SKILL.md                  # migrated from task-parallelization plugin
│   └── task-management/
│       └── SKILL.md                  # new — task lifecycle and naming conventions
└── README.md
```

## Migration from Previous Plugins

If you used `todo-plus-plus`, `todo-sync`, and/or `task-parallelization`:

1. Install `task-utils`
2. Remove the old plugins from `enabledPlugins`
3. Configure `providers.githubIssues` if you used todo-sync's GitHub sync

No data migration required — task state lives in Claude Code's native task store.

## License

MIT
