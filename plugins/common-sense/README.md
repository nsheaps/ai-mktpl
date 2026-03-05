# common-sense

Common-sense rules for AI assistant behavior, bundled as a Claude Code plugin.

## What It Does

On session start, this plugin creates a symlink at `.claude/rules/common-sense` pointing to the plugin's bundled `rules/` directory. This makes all rules automatically available as Claude Code context without manually copying files.

## Rules Included

Rules are sourced from:

- **nsheaps/ai-mktpl `.ai/rules/`** — General AI behavior guidelines (task management, code quality, bash scripting, etc.)
- **nsheaps/cept `.claude/rules/`** — Project-specific rules (PR management, task completion criteria, etc.)

## Session Start Behavior

1. Scans `.claude/rules/` for any stale symlinks pointing into `ai-mktpl/plugins/` and removes them
2. Creates (or replaces) the symlink `.claude/rules/common-sense` -> plugin's `rules/` directory
3. If installed at user level (`~/.claude/`), also creates the symlink in the project's `.claude/rules/`

## Installation

Enable via the marketplace in `.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "common-sense@nsheaps-claude-plugins": true
  }
}
```

## Configuration

No configuration required. The plugin works automatically on session start.
