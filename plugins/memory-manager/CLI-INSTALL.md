# CLI Installation (No Chat Required)

You can install and manage plugins directly from your terminal using the `claude` command.

## Install from Command Line

### Add Marketplace

```bash
# Add GitHub marketplace
claude plugin marketplace add nsheaps/.ai

# Or add local marketplace for development
claude plugin marketplace add ~/src/nsheaps/.ai
```

### Install Plugin

```bash
# Install to user scope (default - available in all projects)
claude plugin install memory-manager@nsheaps-ai-plugins

# Install to project scope (shared with team via git)
cd /your/project
claude plugin install memory-manager@nsheaps-ai-plugins --scope project

# Install to local scope (project-specific, gitignored)
cd /your/project
claude plugin install memory-manager@nsheaps-ai-plugins --scope local
```

### List and Manage Plugins

```bash
# List available marketplaces
claude plugin marketplace list

# Update marketplace (or update all with no name)
claude plugin marketplace update nsheaps-ai-plugins

# Update a specific plugin to latest version
claude plugin update memory-manager@nsheaps-ai-plugins

# Enable/disable plugins
claude plugin enable memory-manager@nsheaps-ai-plugins
claude plugin disable memory-manager@nsheaps-ai-plugins

# Uninstall plugin
claude plugin uninstall memory-manager@nsheaps-ai-plugins

# Remove marketplace
claude plugin marketplace remove nsheaps-ai-plugins

# Validate plugin manifest (for development)
claude plugin validate ~/src/nsheaps/.ai/plugins/memory-manager
```

## Quick Setup Script

Save this as `install-memory-manager.sh`:

```bash
#!/bin/bash
set -e

echo "🔧 Installing Memory Manager plugin..."

# Add marketplace
claude plugin marketplace add nsheaps/.ai

# Install plugin
claude plugin install memory-manager@nsheaps-ai-plugins

echo "✅ Installation complete!"
echo ""
echo "Test it by starting claude and saying:"
echo '  "Never use git rebase, prefer merge"'
```

Make it executable and run:

```bash
chmod +x install-memory-manager.sh
./install-memory-manager.sh
```

## Update Script

Save this as `update-plugins.sh`:

```bash
#!/bin/bash
set -e

echo "🔄 Updating plugins..."

# Update marketplace to fetch latest plugin info
claude plugin marketplace update nsheaps-ai-plugins

# Update the plugin to latest version
claude plugin update memory-manager@nsheaps-ai-plugins

echo "✅ Update complete!"
echo "⚠️  Restart Claude Code to apply changes"
```

## Check What's Installed

```bash
# See all marketplaces
claude plugin marketplace list

# Check settings file directly to see installed plugins
cat ~/.claude/settings.json | jq '.enabledPlugins'

# Or view the entire settings
cat ~/.claude/settings.json | jq '.'

# For project-specific plugins
cat .claude/settings.json | jq '.enabledPlugins'
```

**Note:** There doesn't appear to be a `claude plugin list` command. Use the settings files or the `/plugin` slash command in chat to see installed plugins.

## Troubleshooting

If `claude plugin` doesn't work:

1. **Check Claude CLI is installed:**
   ```bash
   which claude
   claude --version
   ```

2. **Check help:**
   ```bash
   claude --help
   claude plugin --help
   ```

3. **Verify marketplace path:**
   ```bash
   ls ~/src/nsheaps/.ai/.claude-plugin/marketplace.json
   ```

## Configuration Files

Plugins are configured in these files:

- **User scope**: `~/.claude/settings.json`
- **Project scope**: `<project>/.claude/settings.json`
- **Local scope**: `<project>/.claude/settings.local.json` (gitignored)

You can also manually edit these files:

```json
{
  "enabledPlugins": ["memory-manager@nsheaps-ai-plugins"],
  "extraKnownMarketplaces": {
    "nsheaps-ai-plugins": {
      "source": {
        "source": "github",
        "repo": "nsheaps/.ai"
      }
    }
  }
}
```

After manually editing, restart Claude or run:
```bash
claude plugin list  # to refresh
```
