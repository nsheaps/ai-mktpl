# Plugin: agent-tab-titles

**Purpose**: Set tmux/iTerm2 tab titles to agent roles in Claude Code agent team sessions.

## Hooks
- `SessionStart` (`bash`) — Set tmux window/pane titles to agent role on session start. Disables Claude Code LLM-generated titles via env var.
