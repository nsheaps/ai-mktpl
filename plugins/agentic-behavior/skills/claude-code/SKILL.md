---
name: claude-code
description: >-
  Reference material for Claude Code internals — the on-disk layout under
  ~/.claude and project-scope .claude, the plugin cache, session-env
  propagation, and the full hook lifecycle. Auto-recall when working on
  Claude-Code-related tasks: writing or debugging hooks, authoring plugins,
  inspecting session state, troubleshooting why an env var is or isn't
  visible to a Bash tool call, or when paths under ~/.claude or
  ~/.claude/plugins/ come up.
argument-hint: "[topic]"
user-invocable: false
---

<!-- TODO: This skill will be moved to a future "claude-code" plugin in ai-mktpl that absorbs the upstream claude-plugins-official/plugin-dev and skill-dev plugins. -->

# Claude Code Internals

Reference material for how Claude Code (the CLI harness) is laid out on disk
and how its hook system works. This is auto-recalled when an agent needs to
reason about Claude Code internals; the body here is intentionally short so it
doesn't bloat context. **Read the supplementary docs in this directory for
detail when the task warrants it.**

## When to read which doc

| Task                                                                             | Doc                                                              |
| -------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| "Where does Claude store sessions / projects / plugins?"                         | [folder-structure.md](folder-structure.md)                       |
| "What's in `~/.claude/session-env/<id>/` and is it a leak?"                      | [folder-structure.md](folder-structure.md) (session-env section) |
| "How is project path encoded under `~/.claude/projects/`?"                       | [folder-structure.md](folder-structure.md)                       |
| "What hook events exist? When does X fire?"                                      | [hooks.md](hooks.md)                                             |
| "What JSON does a `PreToolUse` hook receive / return?"                           | [hooks.md](hooks.md)                                             |
| "Difference between `command`, `prompt`, `agent`, `http`, `mcp_tool` hook types" | [hooks.md](hooks.md)                                             |
| "How do SessionStart hooks propagate env to Bash calls?"                         | [hooks.md](hooks.md) (CLAUDE_ENV_FILE section)                   |

## Quick orientation

- **User-scope state**: `~/.claude/` (shared across projects on this machine)
- **Project-scope state**: `<repo>/.claude/` (committed to the repo, project-specific)
- **Plugin cache**: `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`
- **Hooks** are configured in `settings.json` under a top-level `hooks` key,
  or bundled inside a plugin at `<plugin>/hooks/hooks.json`.

## Related skills and plugins

- `plugin-dev:plugin-structure` — authoring plugin manifests and layout
- `plugin-dev:hook-development` — writing hooks (events, output contracts)
- `plugin-dev:skill-development` — authoring skills like this one
- `update-config` — modifying `settings.json` / `settings.local.json`

## Source of truth

When this skill and the official docs disagree, **the official docs win**:
<https://code.claude.com/docs/en/hooks>. File a follow-up to update this
skill if you find a discrepancy.
