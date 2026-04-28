# Plugin Development Guide

## Hook Setup

Claude Code auto-discovers `hooks/hooks.json` at the standard path inside each plugin directory. **Do NOT add `"hooks": "./hooks/hooks.json"` to plugin.json** — this causes the same file to load twice, producing ERROR-level duplicate hook logs.

### Correct setup

```
my-plugin/
  .claude-plugin/
    plugin.json          # NO "hooks" field needed
  hooks/
    hooks.json           # Auto-discovered by Claude Code
    scripts/
      my-hook.sh
```

### When to use the `hooks` field

Only use `"hooks"` in plugin.json if the hooks file is at a **non-standard path** (not `hooks/hooks.json`). For example:

```json
{
  "hooks": "./custom-hooks/special-hooks.json"
}
```

## Plugin.json Required Fields

```json
{
  "name": "my-plugin",
  "version": "0.1.0",
  "description": "What the plugin does",
  "author": {
    "name": "Nathan Heaps",
    "email": "nsheaps@gmail.com",
    "url": "https://github.com/nsheaps"
  },
  "homepage": "https://github.com/nsheaps/ai-mktpl/tree/main/plugins/my-plugin",
  "repository": "https://github.com/nsheaps/ai-mktpl"
}
```

## Hook Event Types

| Event | Plugin hooks.json | Notes |
|-------|:--:|-------|
| SessionStart | Works | Fires on session init |
| UserPromptSubmit | Works | Fires on each user message |
| PreToolUse | Known bug — does not fire from plugins | Use settings.json as workaround ([#6305](https://github.com/anthropics/claude-code/issues/6305)) |
| PostToolUse | Known bug — does not fire from plugins | Same issue as PreToolUse |
| Stop | Works | Fires on session end |
| PreCompact | Works | Fires before compaction |
| PostCompact | Works | Fires after compaction |

## Version Bumping

Plugin versions are auto-bumped by CI when code changes are detected in a PR. Do not manually bump versions unless the auto-bump fails to detect changes.
