# Plugin Hooks Organization

## External Hooks Files

**Prefer external hooks files over inline hooks in plugin.json.**

When a plugin needs hooks, define them in a separate file rather than inline in plugin.json:

```
plugins/my-plugin/
├── .claude-plugin/
│   └── plugin.json      # References hooks file
├── hooks/
│   └── hooks.json       # Hook definitions
└── ...
```

## Path Reference Syntax

**CRITICAL:** Hook file paths in plugin.json are relative to the **plugin root**, not the plugin.json file location.

```json
// In .claude-plugin/plugin.json
{
  "name": "my-plugin",
  "hooks": "./hooks/hooks.json"   // Correct: relative to plugin root
}
```

**Common mistake:**

```json
{
  "hooks": "../hooks/hooks.json"  // WRONG: traverses outside plugin root
}
```

The path `../` fails because:

1. Paths are resolved from the plugin root, not from `.claude-plugin/`
2. Traversing outside the plugin root is not allowed
3. When installed, plugins are copied to a cache - external references won't exist

## External Hooks File Structure

The hooks.json file should follow this schema:

```json
{
  "description": "Optional description of hooks",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/my-script.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

**Key points:**

- Use `${CLAUDE_PLUGIN_ROOT}` in command paths for absolute plugin directory
- Hook event names are case-sensitive (e.g., `SessionStart`, not `sessionStart`)
- Supported events: `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Stop`, etc.

## Why External Files

1. **Maintainability**: Hook logic stays separate from plugin metadata
2. **Readability**: plugin.json stays concise and focused on manifest info
3. **Consistency**: Standard location makes hooks easy to find across plugins
4. **Reusability**: Hooks file can be referenced or documented independently

## See Also

- [Plugin Development](plugin-development.md) - Plugin structure requirements
- [Claude Code Plugins Reference](https://code.claude.com/docs/en/plugins-reference)
