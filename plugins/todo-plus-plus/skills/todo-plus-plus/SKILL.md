---
name: todo-plus-plus
description: Task workflow enforcement plugin. Use when asking about commit-on-complete behavior, task completion requirements, ephemeral session awareness, or why a task completion was blocked.
---

# Todo++ Plugin

This plugin enforces two workflow rules for Claude Code sessions:

## 1. Commit-on-Complete

A **TaskCompleted** hook checks for uncommitted changes when any task is marked complete. If there are uncommitted or unpushed changes, the completion is **blocked** until you commit and push.

### Why

Agents frequently complete work but forget to commit. In ephemeral sessions (teammates, sub-agents), uncommitted work is **lost** when the session ends. This hook prevents that.

### What Gets Checked

1. **Uncommitted changes**: Any staged, unstaged, or untracked files (`git status --porcelain`)
2. **Unpushed commits**: Local commits that haven't been pushed to the remote

### If Blocked

When task completion is blocked:
1. Run `git status` to see what needs attention
2. Stage and commit your changes
3. Push to remote
4. Then mark the task complete again

### Exceptions

- If not in a git repository, the check is skipped
- The hook only fires on TaskCompleted events (team task system)

## 2. Ephemeral Session Awareness

A **SessionStart** hook injects a reminder that:

- Tasks (TaskCreate/TaskUpdate/TaskList) are for **local session work only**
- Tasks do NOT persist across sessions
- Persistent tracking belongs in external systems (GitHub Issues, Linear, etc.)
- Always commit and push before marking tasks complete

### Why

Agents sometimes use the Task system as if it were a persistent project tracker, creating tasks they expect to survive session boundaries. This wastes context and creates confusion when tasks disappear.

## Configuration

No configuration required. Install the plugin and it works automatically.

## Disabling

To temporarily disable commit enforcement, you can:
1. Disable the plugin in settings.json
2. Or remove the plugin from enabledPlugins
