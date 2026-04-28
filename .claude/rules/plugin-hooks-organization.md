# Plugin Hooks Organization

Claude Code auto-discovers `hooks/hooks.json` at the standard path inside each plugin. **Do NOT add `"hooks": "./hooks/hooks.json"` to plugin.json** — this causes duplicate loading errors.

## Correct Pattern

```
plugins/my-plugin/
├── .claude-plugin/
│   └── plugin.json      # NO "hooks" field — auto-discovered
└── hooks/
    └── hooks.json       # Auto-discovered by Claude Code
```

## When to use the `hooks` field

Only set `"hooks"` in plugin.json if hooks are at a **non-standard path** (not `hooks/hooks.json`):

```json
{ "hooks": "./custom-hooks/special-hooks.json" }
```

Paths are **relative to the plugin root**, not the plugin.json location.

## Why no explicit reference for the standard path?

Setting `"hooks": "./hooks/hooks.json"` when the file is at the auto-discovered location causes Claude Code to load it twice, producing ERROR-level duplicate hook logs on every session start. The CI validation workflow (`mise run validate`) now catches this.

For hooks.json schema and detailed documentation, use the `claude-code-guide` agent.
