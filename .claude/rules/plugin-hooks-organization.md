# Plugin Hooks Organization

**Use external hooks files, not inline hooks in plugin.json.**

## Correct Pattern

```
plugins/my-plugin/
├── .claude-plugin/
│   └── plugin.json      # "hooks": "./hooks/hooks.json"
└── hooks/
    └── hooks.json
```

## Path Reference

Paths are **relative to the plugin root**, not the plugin.json location:

```json
// Correct
{ "hooks": "./hooks/hooks.json" }

// Wrong - traverses outside plugin root
{ "hooks": "../hooks/hooks.json" }
```

For hooks.json schema and detailed documentation, use the `claude-code-guide` agent.
