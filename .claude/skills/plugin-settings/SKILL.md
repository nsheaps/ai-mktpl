---
name: plugin-settings
description: |
  Help developers work with the plugin settings framework.
  Create, debug, and test plugin configurations.
---

# Plugin Settings Skill

Use this skill to work with the plugin settings framework for Claude Code plugins.

## Creating Plugin Settings

Add settings to `.claude/plugins.settings.json`:

```json
{
  "my-plugin": {
    "target": "local",
    "env": {
      "VAR_NAME_1": "value1",
      "VAR_NAME_2": "value2"
    }
  }
}
```

## Debugging Settings

```bash
# Check settings file exists
cat .claude/plugins.settings.json | jq '.["my-plugin"]'

# Test settings loading
source .claude/lib/load-plugin-settings.sh
load_plugin_settings "my-plugin" | jq .
```

## Testing Configurations

Run the plugin's configuration test:

```bash
just test-plugin-config my-plugin
```

This verifies:

- Hook execution succeeds
- No uncommitted changes to tracked files
- Target files are created correctly

## Common Issues

### Settings Not Loading

1. Check file exists: `cat .claude/plugins.settings.json`
2. Verify JSON syntax: `jq . .claude/plugins.settings.json`
3. Ensure top-level key matches plugin name exactly

### Changes Appearing in Git

1. Set `target: "local"` to use gitignored settings.local.json
2. Verify `.gitignore` includes `.claude/settings.local.json`
3. Run test script to validate: `just test-plugin-config plugin-name`

## Available Functions

- `load_plugin_settings "name"` - Load settings JSON for a plugin
- `get_target "$settings"` - Get target setting (defaults to "local")
- `get_env "$settings"` - Get env object (defaults to {})
- `resolve_target_file "$target"` - Convert target to file path
