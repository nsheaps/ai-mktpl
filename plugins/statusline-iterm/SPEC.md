# Plugin: statusline-iterm

**Purpose**: Status line for Claude Code with iTerm2 badge integration - shows session info, project context, git status, and updates iTerm2 badge.

## Hooks
- `SessionStart` (`bash`) — Automatically configure statusLine.command in user's settings.json to use this plugin's script
- `UserPromptSubmit` (`bash`) — Automatically configure statusLine.command in user's settings.json to use this plugin's script
