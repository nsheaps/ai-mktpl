# Statusline iTerm Plugin

Status line for Claude Code with iTerm2 badge integration - shows session info, project context, git status, and updates iTerm2 badge.

## Overview

This plugin is a fork of the `statusline` plugin that adds iTerm2 badge integration. In addition to displaying the standard status line, it also sets an iTerm2 user variable (`user.badge`) that can be displayed as a badge in your terminal.

## Features

✅ **Session tracking** - Shows current session ID
✅ **Project context** - Displays project and working directory
✅ **Git status** - Shows branch, repository, and change count
✅ **Usage tracking** - Integrates with par-cc-usage (optional)
✅ **Auto-configuration** - Hooks automatically update settings.json
✅ **Worktree support** - Handles git worktrees correctly
✅ **iTerm2 badge** - Updates iTerm2 badge with repo/branch/status

## iTerm2 Badge

The plugin sets the `user.badge` variable with:

```
nsheaps/dotfiles
main ↑2 ↓1 ✗
```

- **Line 1**: owner/repo name
- **Line 2**: branch + ahead (↑) + behind (↓) + clean (✓) or dirty (✗)

### iTerm2 Configuration

To display the badge, configure your iTerm2 profile:

1. Open iTerm2 Preferences → Profiles → [Your Profile] → General
2. Set Badge to: `\(user.badge)`
3. Optionally adjust badge appearance in the same settings

Or use Dynamic Profiles with:

```json
{
  "Badge Text": "\\(user.badge)"
}
```

## Installation

```bash
# Via GitHub
claude plugins install github:nsheaps/.ai/plugins/statusline-iterm

# Or locally for testing
cc --plugin-dir /path/to/plugins/statusline-iterm
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

## Dependencies

### Required

- `bash` - Shell interpreter
- `jq` - JSON parsing
- `git` - Git status display

### Optional

- `uvx` and `par-cc-usage` - Token usage tracking (degrades gracefully if missing)
- iTerm2 - For badge display (degrades gracefully in other terminals)

## Troubleshooting

### Badge not appearing in iTerm2

1. Ensure you're running iTerm2 (check `$TERM_PROGRAM`)
2. Verify your profile has Badge Text set to `\(user.badge)`
3. Check that the statusline script is being called

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

## Development

### Testing Script Changes

```bash
# Test with sample input (in iTerm2)
echo '{"session_id": "test", "workspace": {"project_dir": "'"$PWD"'"}}' | \
  ./bin/statusline.sh
```

## Related Plugins

- **statusline** - Original statusline plugin (without iTerm2 badge)
- **commit-skill** - Automatic git commit management

## Support

- **Issues**: [GitHub Issues](https://github.com/nsheaps/.ai/issues)
- **Documentation**: [Main README](../../README.md)

## License

MIT
