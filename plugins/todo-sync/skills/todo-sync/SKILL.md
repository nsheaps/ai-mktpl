---
name: Todo Sync
description: Automatically syncs todos and plans from ~/.claude/ to the current project. Use this skill when asking about todo sync behavior, troubleshooting sync issues, or understanding where todos are stored.
---

# Todo Sync Plugin

This plugin automatically synchronizes your todos and plans from the global Claude directory (`~/.claude/`) to your current project's `.claude/` directory.

## How It Works

The plugin uses a **PostToolUse hook** that triggers after every `TodoWrite` tool call:

1. When you create or update todos using TodoWrite, the hook fires
2. The sync script finds your session's todo file in `~/.claude/todos/`
3. It merges the todos into `.claude/todos/` in your project
4. It also syncs any plan files from `~/.claude/plans/` to `.claude/plans/`

## File Locations

### Source (Global)

- **Todos**: `~/.claude/todos/{session-id}.json`
- **Plans**: `~/.claude/plans/{plan-name}.md`

### Destination (Project)

- **Todos**: `.claude/todos/{session-id}.json`
- **Plans**: `.claude/plans/{plan-name}.md`

## Merge Behavior

**Todos**: When both source and destination files exist, todos are merged by deduplicating on the `content` field. This prevents duplicate todo entries.

**Plans**: Plans are copied if the source is newer than the destination or if the destination doesn't exist.

## Troubleshooting

### Todos not syncing

1. Check if `~/.claude/todos/` contains files for your session
2. Verify the plugin is enabled: look for it in `/plugins` command output
3. Check hook execution with `claude --debug`

### Permission errors

The script creates directories automatically. If you see permission errors:

1. Ensure you have write access to your project directory
2. Check that `.claude/` isn't gitignored with restrictive permissions

### Empty todo files

Files containing only `[]` (empty arrays) are skipped during sync to avoid cluttering the project.

## Integration with Git

The plugin automatically adds patterns to `.claude/.gitignore` for `todos/` and `plans/` directories. This prevents synced files from being committed by default.

If you want to track todos in version control for persistent project-specific task tracking, remove these patterns from `.claude/.gitignore`.

## Manual Sync

The sync happens automatically on TodoWrite. If you need to manually trigger it, simply update your todos:

```
TodoWrite: [your todos here]
```

The hook will fire and sync will occur.
