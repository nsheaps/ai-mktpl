# Statusline Plugin

Configurable status line for Claude Code showing session info, project context, and git status.

## Overview

This plugin provides an informative status line that displays at the top of your Claude Code sessions. It automatically configures itself on installation and updates to show real-time information about your workspace.

## Features

✅ **Session tracking** - Shows current session ID
✅ **Project context** - Displays project and working directory
✅ **Git status** - Shows branch, repository, and change count
✅ **Usage tracking** - Integrates with par-cc-usage (optional)
✅ **Auto-configuration** - Hooks automatically update settings.json
✅ **Worktree support** - Handles git worktrees correctly

## Installation

See [Installation Guide](../../docs/installation.md) for all installation methods.

### Quick Install

```bash
# Via marketplace (recommended)
# Follow marketplace setup: ../../docs/manual-installation.md

# Or via GitHub
claude plugins install github:nsheaps/.ai/plugins/statusline

# Or locally for testing
cc --plugin-dir /path/to/plugins/statusline
```

### What Happens on Install

The plugin includes hooks that automatically configure your `~/.claude/settings.json`:

1. On SessionStart and UserPromptSubmit, the hook checks your settings
2. If `statusLine.command` is not configured, it sets it to this plugin's script
3. If already pointing to this plugin, it updates silently (handles plugin path changes)
4. If pointing to a different script, it warns and asks you to choose

## Status Line Output

The status line displays:

```
Session: abc-123-def-456
In: ~/src/project | In: ./src/components
On: org/repo@feature-branch (3 changes)
Usage: 50K tokens (5% of limit)
```

### Line Breakdown

- **Session**: Current Claude Code session ID
- **In**: Project root and current working directory (abbreviated)
- **On**: Git repository (org/name), branch, and change count
- **Usage**: Token usage from par-cc-usage (if available)

## How It Works

### Hook-Based Configuration

The plugin uses SessionStart and UserPromptSubmit hooks to ensure settings.json always points to the latest version of the statusline script:

1. **On session start**: Configure statusline if not set
2. **On each prompt**: Verify configuration is current
3. **On plugin update**: Update path automatically

This ensures the statusline always uses the plugin's script, even after plugin updates or moves.

### Script Execution

Claude Code calls `bin/statusline.sh`:

- Receives JSON with session and workspace info via stdin
- Extracts relevant data (session ID, paths, git status)
- Outputs formatted lines to display
- Runs fast (<100ms) to avoid UI lag

## Customization

Want to modify what the statusline shows? See [CLAUDE.md](./CLAUDE.md) for:

- Adding new status lines
- Removing existing lines
- Integrating external tools
- Performance considerations
- Testing changes

**Note**: Since this is a plugin, modifications should be made to the plugin source code. For user-specific customizations, fork the plugin or maintain a local copy.

## Dependencies

### Required

- `bash` - Shell interpreter
- `jq` - JSON parsing
- `git` - Git status display

### Optional

- `uvx` and `par-cc-usage` - Token usage tracking (degrades gracefully if missing)

Install required dependencies:

```bash
# Via mise (recommended)
mise use -g jq

# Via Homebrew
brew install jq git

# Via apt
sudo apt-get install jq git
```

## Troubleshooting

### Statusline not appearing

1. Check if the plugin is enabled:

   ```bash
   jq '.enabledPlugins' ~/.claude/settings.json
   ```

2. Verify settings.json configuration:

   ```bash
   jq '.statusLine' ~/.claude/settings.json
   ```

3. Restart Claude Code

### Wrong script path

If the statusline shows an error about the script not being found:

1. Check the path in settings.json:

   ```bash
   jq -r '.statusLine.command' ~/.claude/settings.json
   ```

2. Verify the script exists:

   ```bash
   ls -l "$(jq -r '.statusLine.command' ~/.claude/settings.json)"
   ```

3. The hook should auto-fix on next prompt, or restart Claude Code

### Hook warning appears

If you see a warning about statusline configuration conflict:

The plugin detected you're using a different statusline script. Choose one:

**Option 1: Use this plugin's statusline**

```bash
# Manually update settings.json
jq '.statusLine.command = "~/.claude/plugins/statusline/bin/statusline.sh"' \
  ~/.claude/settings.json > ~/.claude/settings.json.tmp
mv ~/.claude/settings.json.tmp ~/.claude/settings.json
```

**Option 2: Keep your current statusline**

```bash
# Disable this plugin
jq '.enabledPlugins["statusline@nsheaps"] = false' \
  ~/.claude/settings.json > ~/.claude/settings.json.tmp
mv ~/.claude/settings.json.tmp ~/.claude/settings.json
```

### Missing git info

If git information doesn't appear:

- Ensure you're in a git repository
- Check git is installed: `which git`
- Verify repository has a remote: `git remote -v`

### Usage tracking not showing

The par-cc-usage integration is optional:

- Install with: `uvx install par-cc-usage`
- Or ignore - the script degrades gracefully

## Configuration

The plugin configures these settings automatically:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/path/to/plugins/statusline/bin/statusline.sh"
  }
}
```

**Note**: The exact path is resolved by the plugin hooks and may vary based on installation method.

## Development

### Testing Script Changes

```bash
# Test with sample input
echo '{"session_id": "test", "workspace": {"project_dir": "'"$PWD"'"}}' | \
  ./bin/statusline.sh
```

### Testing Hook Configuration

```bash
# Validate hooks.json schema
~/.claude/plugins/cache/claude-plugins-official/plugin-dev/*/scripts/validate-hook-schema.sh hooks/hooks.json

# Test hook script
echo '{}' | bash hooks/configure-statusline.sh
echo "Exit code: $?"
```

### Debug Mode

Run Claude Code with debugging:

```bash
claude --debug
```

Look for statusline hook execution logs.

## Related Plugins

- **commit-skill** - Automatic git commit management
- **sync-settings** - Synchronize settings across machines

## Support

- **Issues**: [GitHub Issues](https://github.com/nsheaps/.ai/issues)
- **Documentation**: [Main README](../../README.md)
- **Claude Code Docs**: [https://code.claude.com/docs](https://code.claude.com/docs)

## Changelog

See CHANGELOG.md for version history.

## License

MIT
