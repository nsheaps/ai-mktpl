# Quick Installation Guide

## Install Memory Manager Plugin

### Option 1: Install from GitHub (Recommended)

```bash
# 1. Add the GitHub marketplace
/plugin marketplace add nsheaps/.ai

# 2. Install the memory-manager plugin
/plugin install memory-manager@nsheaps-ai-plugins

# 3. Verify installation
/plugin
```

### Option 2: Install from Local Development Version

```bash
# 1. Add the local marketplace
/plugin marketplace add ~/src/nsheaps/.ai

# 2. Install the memory-manager plugin
/plugin install memory-manager@nsheaps-ai-plugins

# 3. Verify installation
/plugin
```

You should see `memory-manager@nsheaps-ai-plugins` in your installed plugins list.

## Updating the Plugin

To get the latest version:

```bash
# 1. Update the marketplace
/plugin marketplace update nsheaps-ai-plugins

# 2. Reinstall the plugin to get updates
/plugin uninstall memory-manager@nsheaps-ai-plugins
/plugin install memory-manager@nsheaps-ai-plugins
```

Or simply ask Claude: "update my memory manager plugin"

## Test the Skill

Try saying one of these phrases to test the memory manager:

- "Never use git rebase, always prefer merge"
- "Don't forget to run tests before committing"
- "Always use TypeScript in this project"

You should see a response like:
```
🧠 I'll remember to [what you said]
📝 Wrote [filename]
```

## Troubleshooting

If the plugin doesn't appear:

```bash
# Update the marketplace
/plugin marketplace update nsheaps-ai-plugins

# Try installing again
/plugin install memory-manager@nsheaps-ai-plugins
```

If the skill doesn't activate:

```bash
# Check if it's installed
/plugin

# Manually invoke it
/skill memory-manager
```
