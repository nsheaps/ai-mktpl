# Manual Installation via settings.json

Guide for manually configuring plugins by editing `~/.claude/settings.json`.

## Why Manual Installation?

Manual installation is useful for:

- CI/CD environments without interactive sessions
- Batch enabling multiple plugins
- Understanding plugin configuration internals
- Troubleshooting installation issues
- Setting up fresh environments

## Prerequisites

1. Claude Code installed
2. Text editor (vim, nano, VSCode, etc.)
3. Basic understanding of JSON

## Adding the Marketplace

To install plugins from this marketplace, add it to your Claude Code configuration:

### Step 1: Open settings.json

```bash
# Open in your preferred editor
code ~/.claude/settings.json
# or
vim ~/.claude/settings.json
# or
nano ~/.claude/settings.json
```

### Step 2: Add marketplace configuration

If your `settings.json` doesn't have a `marketplaces` field, add it:

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "marketplaces": [
    {
      "name": "nsheaps",
      "url": "https://raw.githubusercontent.com/nsheaps/ai-mktpl/main/.claude-plugin/marketplace.json"
    }
  ],
  "enabledPlugins": {
    // ... existing plugins ...
  }
}
```

If you already have marketplaces, add the nsheaps marketplace to the array:

```json
{
  "marketplaces": [
    {
      "name": "official",
      "url": "https://marketplace.claude.ai/v1/marketplace.json"
    },
    {
      "name": "nsheaps",
      "url": "https://raw.githubusercontent.com/nsheaps/ai-mktpl/main/.claude-plugin/marketplace.json"
    }
  ]
}
```

### Step 3: Save and verify

Save the file and verify the marketplace is recognized:

```bash
# In a Claude Code session
/marketplace list
```

You should see "nsheaps" in the list.

## Enabling Plugins Manually

### Method 1: Via GitHub (No marketplace needed)

Enable a plugin directly from GitHub:

```json
{
  "enabledPlugins": {
    "plugin-name@github:nsheaps/ai-mktpl": true
  }
}
```

### Method 2: Via Marketplace (After adding marketplace)

Once the marketplace is configured, enable plugins by name:

```json
{
  "enabledPlugins": {
    "plugin-name@nsheaps": true
  }
}
```

### Method 3: Via Local Path (Development)

For local development or testing:

```json
{
  "enabledPlugins": {
    "plugin-name@file:///Users/you/path/to/plugins/plugin-name": true
  }
}
```

## Complete Example

Here's a complete example `settings.json` with marketplace and plugins:

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "marketplaces": [
    {
      "name": "official",
      "url": "https://marketplace.claude.ai/v1/marketplace.json"
    },
    {
      "name": "nsheaps",
      "url": "https://raw.githubusercontent.com/nsheaps/ai-mktpl/main/.claude-plugin/marketplace.json"
    }
  ],
  "enabledPlugins": {
    "commit-skill@nsheaps": true,
    "data-serialization@nsheaps": true,
    "statusline@github:nsheaps/ai-mktpl": true
  },
  "model": "sonnet",
  "permissions": {
    "defaultMode": "acceptEdits"
  }
}
```

## Plugin Sources Explained

### Format: `plugin-name@source`

- `@nsheaps` - From nsheaps marketplace (requires marketplace config)
- `@github:org/repo` - From GitHub repository
- `@file:///path` - From local filesystem
- `@official` - From official Claude Code marketplace

### Full GitHub Path

For plugins in subdirectories:

```json
{
  "enabledPlugins": {
    "commit-skill@github:nsheaps/ai-mktpl/plugins/commit-skill": true
  }
}
```

## Disabling Plugins

Set the plugin value to `false`:

```json
{
  "enabledPlugins": {
    "plugin-name@nsheaps": false
  }
}
```

Or remove the entry entirely.

## Verifying Configuration

After editing `settings.json`:

### Check JSON syntax

```bash
# Verify JSON is valid
jq . ~/.claude/settings.json
```

If jq returns an error, fix the JSON syntax.

### Check enabled plugins

```bash
# List enabled plugins
jq '.enabledPlugins' ~/.claude/settings.json
```

### Restart Claude Code

Changes to `settings.json` require restarting Claude Code:

```bash
# Exit current session (Ctrl+D or exit command)
# Start new session
cc
```

## Troubleshooting

### Invalid JSON

If Claude Code won't start after editing:

```bash
# Validate JSON
jq . ~/.claude/settings.json

# If errors, fix them or restore backup
cp ~/.claude/settings.json.bak ~/.claude/settings.json
```

### Plugin not loading

1. Check JSON syntax with `jq`
2. Verify plugin name spelling
3. Check marketplace URL is accessible
4. Restart Claude Code
5. Review plugin requirements in its README

### Marketplace not found

If plugins from marketplace aren't loading:

1. Verify marketplace URL is correct
2. Check network connectivity
3. Test URL in browser: should return JSON
4. Ensure marketplace name matches (case-sensitive)

## Best Practices

1. **Backup before editing**: `cp ~/.claude/settings.json ~/.claude/settings.json.bak`
2. **Validate JSON**: Use `jq` to check syntax after edits
3. **One change at a time**: Add plugins incrementally
4. **Use version control**: Track your settings.json in git
5. **Comment your config**: Use JSON5 or external docs to explain settings

## Schema Validation

Claude Code settings follow a JSON schema. Your editor may provide validation:

### VSCode

The `$schema` field enables IntelliSense:

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json"
}
```

### Command Line

Validate against schema:

```bash
# Install ajv-cli if needed
npm install -g ajv-cli

# Validate
ajv validate -s https://json.schemastore.org/claude-code-settings.json -d ~/.claude/settings.json
```

## Additional Resources

- [Installation Guide](./installation.md) - Other installation methods
- [Claude Code Settings Schema](https://json.schemastore.org/claude-code-settings.json)
- [Claude Code Documentation](https://code.claude.com/docs)
- [Plugin Marketplace](https://github.com/nsheaps/ai-mktpl)
