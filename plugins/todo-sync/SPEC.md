# Plugin: todo-sync

**Purpose**: Automatically syncs todos and plans from `~/.claude/` to your current project's `.claude/` directory.

## Skills

- `todo-sync` — Automatically syncs todos and plans from ~/.claude/ to the current project. Use this skill when asking about todo sync...

## Hooks

- `SessionStart` (`bash`) — Syncs todos and plans from ~/.claude/ to project .claude/ directory after TodoWrite
- `UserPromptSubmit` (`bash`) — Syncs todos and plans from ~/.claude/ to project .claude/ directory after TodoWrite
- `PostToolUse` (`bash`) — Syncs todos and plans from ~/.claude/ to project .claude/ directory after TodoWrite
