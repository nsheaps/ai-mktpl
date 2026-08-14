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

| Event               | Plugin hooks.json | Notes                                                                          |
| ------------------- | :---------------: | ------------------------------------------------------------------------------ |
| SessionStart        |       Works       | Fires on session init                                                          |
| UserPromptSubmit    |       Works       | Fires on each user message                                                     |
| PreToolUse          |       Works       | Fixed upstream; see the note below before trusting older workarounds           |
| PostToolUse         |       Works       | Same as PreToolUse                                                             |
| PostToolUseFailure  |       Works       | Same as PreToolUse                                                             |
| PermissionRequest   |     Untested      | Not observed firing or failing to fire; no run has reached a permission prompt |
| Stop                |       Works       | Fires on session end / clear / resume / compact                                |
| PreCompact          |       Works       | Fires before compaction (matcher: "manual" or "auto")                          |
| PostCompact         |       Works       | Fires after compaction (receives summary)                                      |
| Notification        |       Works       | Fires on notification events                                                   |
| TaskCompleted       |       Works       | Fires when a task is marked completed                                          |
| TaskCreated         |     Untested      | Fires when a task is created                                                   |
| SubagentStart       |     Untested      | Fires when a sub-agent launches                                                |
| SubagentStop        |     Untested      | Fires when a sub-agent completes                                               |
| UserPromptExpansion |     Untested      | Fires during prompt expansion                                                  |

**Note on the tool-dispatch events.** This table used to mark `PreToolUse`, `PostToolUse`, `PostToolUseFailure` and `PermissionRequest` as "Bug — does not fire", on an empirical confirmation from **v2.1.128 CLI (2026-05-19)** and citing [#6305](https://github.com/anthropics/claude-code/issues/6305) / [#40506](https://github.com/anthropics/claude-code/issues/40506). That is no longer the behaviour.

Re-tested on **v2.1.231 (2026-08-14)**: a plugin loaded with `--plugin-dir`, declaring all four events in `hooks/hooks.json`, fired `PreToolUse` three times, `PostToolUse` once and `PostToolUseFailure` once across three Bash tool calls. The same prompt run without the plugin fired nothing, so the markers came from the plugin's own hooks and not from ambient configuration. `PermissionRequest` stays **Untested**: no call in that run reached a permission prompt, so it was neither observed firing nor observed failing to.

Two consequences worth knowing before you copy an existing plugin:

- Several plugins here still carry a settings.json workaround, or an inline note, written while the bug was real. Those are harmless but no longer necessary; sweeping them is tracked in [#753](https://github.com/nsheaps/ai-mktpl/issues/753).
- Re-confirm before writing a version-dependent claim like this one into a rule or a check. The bug was real when recorded and stayed recorded ~90 releases past its fix.

## Version Bumping

Plugin versions are auto-bumped by CI **on merge to `main`** when code changes are detected. PRs only show a preview (a sticky comment plus a `::notice` annotation on each affected `plugin.json`); they do not commit bumps. Do not manually bump versions unless the auto-bump fails to detect changes.
