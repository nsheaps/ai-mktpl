# Plugin: word-vomit

**Purpose**: Claude Code plugin for capturing and processing unstructured thoughts ("word vomit") into organized, actionable work items.

## Skills
- `word-vomit` — Use when the user wants to dump unstructured thoughts, ideas, or notes that need to be organized. Triggers: "brain...

## Hooks
- `PostToolUse` (`bash`) — Detects writes to word-vomit scratch files and prompts exec-assist processing
