# agentic-behavior

Rules for autonomous decision-making, recommendation style, and handler-interaction patterns.

## What It Does

On session start, creates a symlink at `.claude/rules/agentic-behavior` pointing to this plugin's
`rules/` directory, making all rules available as Claude Code context.

## Rules Included

- **autonomy.md** — Autonomy balance, recommendation style, merge approval, and research-first patterns

## Installation

Enable via the marketplace in `.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "agentic-behavior@nsheaps-claude-plugins": true
  }
}
```
