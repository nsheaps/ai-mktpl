# Plugin Installation Guide

Complete guide for installing plugins from the nsheaps/ai-mktpl plugin marketplace.

## Installation Methods

### Method 1: Via Marketplace (Recommended)

First, add the marketplace to your Claude Code configuration. See [Manual Installation Guide](./manual-installation.md#adding-the-marketplace) for details.

Once the marketplace is configured, plugins can be installed via Claude Code:

```bash
# In a Claude Code session
/plugin install plugin-name
```

Or use the GitHub path:

```bash
claude plugins install github:nsheaps/ai-mktpl/plugins/plugin-name
```

### Method 2: Via GitHub URL

Install directly from GitHub without configuring the marketplace:

```bash
claude plugins install github:nsheaps/ai-mktpl/plugins/plugin-name
```

### Method 3: Local Development

For testing or development, use the `--plugin-dir` flag:

```bash
cc --plugin-dir /path/to/plugins/plugin-name
```

Or clone the repository and point to a plugin:

```bash
git clone https://github.com/nsheaps/ai-mktpl.git
cc --plugin-dir ~/.ai/plugins/plugin-name
```

## Manual Installation via settings.json

For advanced users who prefer editing configuration files directly, see the [Manual Installation Guide](./manual-installation.md).

This method is useful for:

- Setting up plugins without CLI commands
- Configuring plugins in CI/CD environments
- Batch enabling multiple plugins
- Understanding how plugin configuration works

## Verifying Installation

After installation, verify the plugin is loaded:

```bash
# In a Claude Code session
/plugins list
```

Or check your settings file:

```bash
cat ~/.claude/settings.json | jq '.enabledPlugins'
```

## Troubleshooting

### Plugin not found

If you get "plugin not found" errors:

1. Check the plugin name is correct
2. Verify the marketplace is configured (Method 1)
3. Try the full GitHub path (Method 2)
4. Check network connectivity

### Plugin not loading

If the plugin is installed but not working:

1. Check `~/.claude/settings.json` for the plugin in `enabledPlugins`
2. Restart Claude Code
3. Check plugin compatibility with your Claude Code version
4. Review plugin README for dependencies

### Permission errors

If you get permission errors:

1. Check file permissions on plugin directory
2. Ensure you have write access to `~/.claude/`
3. Try using `sudo` for system-wide installations (not recommended)

## Updating Plugins

Plugins are updated automatically when you restart Claude Code, or manually:

```bash
claude plugins update
```

Or update a specific plugin:

```bash
claude plugins update plugin-name
```

## Uninstalling Plugins

Remove a plugin:

```bash
claude plugins uninstall plugin-name
```

Or manually edit `~/.claude/settings.json` to remove from `enabledPlugins`.

## Getting Help

- Plugin issues: [GitHub Issues](https://github.com/nsheaps/ai-mktpl/issues)
- Claude Code docs: [https://code.claude.com/docs](https://code.claude.com/docs)
- Marketplace repo: [nsheaps/ai-mktpl](https://github.com/nsheaps/ai-mktpl)
