# context-bloat-prevention

Prevents context window bloat from large tool outputs and oversized conversation history entries.

## Problem

Large tool outputs (>10kB) and oversized JSONL conversation entries cause:

- Context window exhaustion leading to session crashes ([#20470](https://github.com/anthropics/claude-code/issues/20470))
- Inability to compact conversations properly
- Degraded performance as context fills up
- Particularly severe with agent teams (multiple agents, each accumulating context)

## What This Plugin Does

### PostToolUse: Large Output Detection

After tools like Bash, Read, Grep, Glob, WebFetch, and WebSearch execute, checks if the output exceeds 10kB. If so:

1. Saves the full output to `.claude/tmp/large-output-{tool}-{timestamp}.txt`
2. Injects a systemMessage warning Claude to use the file reference instead

### PostToolUse: JSONL Entry Size Check

After Write/Edit operations on `.jsonl` files, checks the last 5 lines for entries exceeding 10kB. Warns Claude to keep JSONL entries compact.

## Limitations

**PostToolUse hooks cannot modify or replace built-in tool output** ([#18594](https://github.com/anthropics/claude-code/issues/18594)). The large output is already in the conversation context by the time the hook fires. This plugin mitigates the problem by:

- Saving the output to a file for future reference (so Claude doesn't need to keep it in working memory)
- Warning Claude to redirect future large outputs to files proactively

True output interception would require upstream changes to Claude Code's hook architecture.

## Configuration

Set the size threshold via environment variable (default: 10240 bytes / 10kB):

```bash
export CONTEXT_BLOAT_THRESHOLD=10240
```

## Installation

Install via the nsheaps-claude-plugins marketplace:

```
context-bloat-prevention@nsheaps-claude-plugins
```
