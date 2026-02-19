# agent-tab-titles

Set tmux/iTerm2 tab titles to agent roles in Claude Code agent team sessions.

## What It Does

1. **Disables LLM-generated titles**: Sets `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` so Claude Code doesn't overwrite tab titles with auto-generated topic summaries
2. **Sets role-based tab titles**: On `SessionStart`, sets the tmux window name and pane title to the agent's name/role

## How It Works

### In tmux (including iTerm2 `-CC` control mode)

- Uses `tmux rename-window` to set the tab title (iTerm2 tabs map to tmux windows in `-CC` mode)
- Uses `tmux select-pane -T` to set the per-pane title
- Disables `automatic-rename` so the title persists

### Outside tmux

- Uses OSC 0 escape sequence (`\033]0;title\007`) to set the native terminal title

## Title Resolution

The hook resolves the tab title using this priority:

1. `CLAUDE_CODE_AGENT_NAME` env var (teammate display name, e.g., "Bugs B (software-eng)")
2. `agent_type` from SessionStart hook input
3. `CLAUDE_CODE_AGENT_TYPE` env var
4. Falls back to "claude"

## Prerequisites

For best results in iTerm2 + tmux:

```
# ~/.tmux.conf
set-option -g set-titles on
set-option -g set-titles-string '#T'

# Optional: show pane titles in split pane mode
set-option -g pane-border-status top
set-option -g pane-border-format " #{pane_index}: #{pane_title} "
```

To see per-pane titles: iTerm2 → Preferences → Appearance → Panes → "Show per-pane title bar with split panes"

## References

- [iTerm2 tmux Integration](https://iterm2.com/documentation-tmux-integration.html)
- [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams)
- [Claude Code Hooks](https://code.claude.com/docs/en/hooks)
- Research: Road Runner's tab title mechanism analysis (agent-team `.claude/tmp/iterm-tmux-tab-naming-research.md`)
