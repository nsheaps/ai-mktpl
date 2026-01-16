# Todo Sync Plugin

Automatically syncs todos and plans from `~/.claude/` to your current project's `.claude/` directory.

## Features

- **Automatic sync**: Triggers after every `TodoWrite` call via PostToolUse hook
- **Smart merge**: Deduplicates todos by content when merging
- **Plans support**: Syncs plan files from global to project directory
- **Session-aware**: Only syncs the current session's todos

## Installation

Add to your project's `.claude/settings.json`:

```json
{
  "plugins": ["/path/to/todo-sync"]
}
```

Or install from the marketplace (if published).

## How It Works

```
TodoWrite called
    ↓
PostToolUse hook fires
    ↓
sync-todos.sh executes
    ↓
~/.claude/todos/{session}.json → .claude/todos/{session}.json
~/.claude/plans/*.md → .claude/plans/*.md
```

## File Structure

```
todo-sync/
├── .claude-plugin/
│   └── plugin.json        # Plugin manifest
├── hooks/
│   └── hooks.json         # Hook configuration (SessionStart, UserPromptSubmit, PostToolUse)
├── scripts/
│   ├── init-gitignore.sh  # Creates .gitignore in target dirs
│   └── sync-todos.sh      # Sync logic
├── skills/
│   └── todo-sync/
│       └── SKILL.md       # Usage documentation
└── README.md
```

## Configuration

No configuration required. The plugin works automatically once installed.

### Git Integration

The plugin automatically creates `.gitignore` files in `.claude/todos/` and `.claude/plans/` on session start and each user prompt. These ignore all synced files by default.

To track todos in version control instead, remove the generated `.gitignore` files.

## Troubleshooting

Run Claude Code in debug mode to see hook execution:

```bash
claude --debug
```

Look for `PostToolUse` events on `TodoWrite` to verify the hook is firing.

## License

MIT
