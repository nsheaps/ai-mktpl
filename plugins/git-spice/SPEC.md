# Plugin: git-spice

**Purpose**: Skill for managing stacked Git branches with [git-spice](https://github.com/abhinav/git-spice) (`gs` CLI tool).

## Skills
- `git-spice` — This skill should be used when the user asks to "create a stacked branch", "stack a branch", "submit stacked PRs",...

## Hooks
- `SessionStart` (`bash`) — git-spice plugin hooks: stack status check and push rejection
- `PreToolUse` (`bash`) — git-spice plugin hooks: stack status check and push rejection
