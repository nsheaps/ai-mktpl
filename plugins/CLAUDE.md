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

All known hook events and their compatibility with plugin `hooks.json`:

| Event               |  Plugin hooks.json  | Notes                                                                                         |
| ------------------- | :-----------------: | --------------------------------------------------------------------------------------------- |
| SessionStart        |        Works        | Fires on session init                                                                         |
| UserPromptSubmit    |        Works        | Fires on each user message                                                                    |
| PreToolUse          | Bug — does not fire | Use settings.json workaround ([#6305](https://github.com/anthropics/claude-code/issues/6305)) |
| PostToolUse         | Bug — does not fire | Same as PreToolUse                                                                            |
| PostToolUseFailure  | Bug — does not fire | Same as PreToolUse                                                                            |
| PermissionRequest   | Bug — does not fire | Same as PreToolUse                                                                            |
| Stop                |        Works        | Fires on session end / clear / resume / compact                                               |
| PreCompact          |        Works        | Fires before compaction (matcher: "manual" or "auto")                                         |
| PostCompact         |        Works        | Fires after compaction (receives summary)                                                     |
| Notification        |        Works        | Fires on notification events                                                                  |
| TaskCompleted       |        Works        | Fires when a task is marked completed                                                         |
| TaskCreated         |      Untested       | Fires when a task is created                                                                  |
| SubagentStart       |      Untested       | Fires when a sub-agent launches                                                               |
| SubagentStop        |      Untested       | Fires when a sub-agent completes                                                              |
| UserPromptExpansion |      Untested       | Fires during prompt expansion                                                                 |

**Note:** Events marked "Bug — does not fire" are tool-dispatch events that use a separate registry from where plugin hooks are stored. Only settings.json hooks fire for these events. See [#6305](https://github.com/anthropics/claude-code/issues/6305) and [#40506](https://github.com/anthropics/claude-code/issues/40506).

## Version Bumping

Plugin versions are auto-bumped by CI **on merge to `main`** when code changes are detected. PRs only show a preview (a sticky comment plus a `::notice` annotation on each affected `plugin.json`); they do not commit bumps. Do not manually bump versions unless the auto-bump fails to detect changes.
