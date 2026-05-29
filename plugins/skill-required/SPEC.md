# Plugin: skill-required

**Purpose**: Claude Code plugin that enforces skill loading before tool use.

## Hooks

- `PostToolUse` (`bash`) — Skill-required enforcement: tracks skill reads and blocks tool use if required skill not recently loaded
- `PreToolUse` (`bash`) — Skill-required enforcement: tracks skill reads and blocks tool use if required skill not recently loaded
