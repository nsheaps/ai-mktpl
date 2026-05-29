# Plugin: context-bloat-prevention

**Purpose**: Prevents context window bloat from large tool outputs and oversized conversation history entries.

## Hooks

- `PostToolUse` (`bash`) — Detect and warn about large tool outputs and oversized JSONL entries to prevent context bloat
