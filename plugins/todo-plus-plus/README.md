# Todo++ Plugin

Enforces commit-on-complete for tasks and provides ephemeral session awareness.

## Features

- **Commit-on-Complete**: Blocks task completion if there are uncommitted or unpushed changes
- **Ephemeral Session Awareness**: Reminds agents that Tasks are session-scoped, not persistent

## Installation

Add to your project or user settings.json enabledPlugins.

## How It Works

### TaskCompleted Hook

When any task is marked complete (via TaskUpdate), the hook:

1. Checks `git status` for uncommitted changes
2. Checks for unpushed commits
3. If either exists, blocks completion with a message telling Claude to commit and push first

### SessionStart Hook

On session start, injects a prompt reminding Claude that:

- Tasks are for local session work only
- Always commit and push before completing tasks
- Use external systems for persistent project tracking

## File Structure

```
todo-plus-plus/
├── .claude-plugin/
│   └── plugin.json
├── hooks/
│   └── hooks.json       # TaskCompleted + SessionStart hooks
├── scripts/
│   └── check-uncommitted.sh  # Git status checker
├── skills/
│   └── todo-plus-plus/
│       └── SKILL.md
└── README.md
```

## Related Plugins

- **todo-sync** -- Syncs todos from ~/.claude/ to project .claude/ (complementary)
- **scm-utils** -- Git workflow utilities

## License

MIT
