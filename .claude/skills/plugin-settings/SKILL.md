---
name: plugin-settings
description: |
  Help developers work with the plugin settings framework.
  Create, debug, and test plugin configurations.
---

# Plugin Settings Skill

Use this skill to work with the plugin settings framework for Claude Code plugins.

## Creating Plugin Settings

### Central Settings (Recommended)

Add settings to `.claude/plugins.settings.yaml`:

```yaml
my-plugin:
  enabled: true
  setting1: value1
  secret: ${ENV_VAR_NAME}
```

### Plugin-Specific Settings

Create `plugins/my-plugin/my-plugin.settings.yaml` to override central settings.

## Debugging Settings Resolution

To trace which settings file is being loaded:

```bash
# Check if plugin-specific file exists
ls -la plugins/my-plugin/my-plugin.settings.{yaml,yml,json} 2>/dev/null

# Check central settings
cat .claude/plugins.settings.yaml | yq '.["my-plugin"]'

# Test settings loading
source .claude/lib/load-plugin-settings.sh
load_plugin_settings "my-plugin" '{}' | jq .
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

1. Check file exists and has correct name
2. Verify YAML/JSON syntax: `yq . file.yaml` or `jq . file.json`
3. Ensure top-level key matches plugin name exactly

### Environment Variable Not Resolving

1. Check variable is exported: `echo $VAR_NAME`
2. Verify syntax uses `${VAR_NAME}` not `$VAR_NAME`
3. Check `resolve_env_var` is called in plugin code

### Changes Appearing in Git

1. Set `target: local` to use gitignored settings.local.json
2. Verify `.gitignore` includes `.claude/settings.local.json`
3. Run test script to validate: `just test-plugin-config plugin-name`

## Available Tools

- `load_plugin_settings "name" "defaults"` - Load settings JSON
- `get_setting "$json" ".key" "default"` - Extract value from settings
- `resolve_env_var "$value"` - Expand environment variable references
