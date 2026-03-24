# Statusline iTerm Plugin

Status line for Claude Code with iTerm2 badge integration - shows session info, project context, git status, and updates iTerm2 badge.

## Overview

This plugin provides an informative status line that displays at the top of your Claude Code sessions, with optional iTerm2 badge integration. It automatically configures itself on installation and updates to show real-time information about your workspace. On iTerm2, it also sets a user variable (`user.badge`) for badge display.

## Features

✅ **Session tracking** - Shows current session ID
✅ **Project context** - Displays project and working directory
✅ **Git status** - Shows branch, repository, and change count
✅ **Usage tracking** - Integrates with par-cc-usage (optional)
✅ **Auto-configuration** - Hooks automatically update settings.json
✅ **Worktree support** - Handles git worktrees correctly
✅ **iTerm2 badge** - Updates iTerm2 badge with repo/branch/status
✅ **Agent team aware** - Automatically disabled for teammates to prevent API rate limit exhaustion

## Agent Teams

When running with [Claude Code agent teams](https://code.claude.com/docs/en/agent-teams), the statusline is automatically disabled for spawned teammates. Only the team lead and solo sessions display the statusline.

**Why**: The statusline makes GitHub API calls (`gh pr view`, `gh repo view`) on every refresh. With 7+ teammates, these calls multiply and exhaust the GitHub API rate limit (~5,000/hour). Since teammates don't have a visible status bar anyway, disabling the script prevents unnecessary API consumption.

**Detection**: Uses `CLAUDE_CODE_PARENT_SESSION_ID`, which Claude Code sets for spawned teammates but not for the lead or solo sessions.

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
claude plugins install github:nsheaps/ai-mktpl/plugins/statusline-iterm

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
- Sets iTerm2 badge variable (gracefully degrades on non-iTerm terminals)
- Runs fast with per-section performance timing

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

### Wrong script path

If the statusline shows an error about the script not being found:

1. Check the path in settings.json:

   ```bash
   jq -r '.statusLine.command' ~/.claude/settings.json
   ```

2. Verify the script exists at that path
3. The hook should auto-fix on next prompt, or restart Claude Code

### Hook warning appears

If you see a warning about statusline configuration conflict, the plugin detected you're using a different statusline script. The plugin will not override your existing configuration automatically — you must choose which statusline to use.

### Missing git info

If git information doesn't appear:

- Ensure you're in a git repository
- Check git is installed: `which git`
- Verify repository has a remote: `git remote -v`

### Usage tracking not showing

The par-cc-usage integration is optional:

- Install with: `uvx install par-cc-usage`
- Or ignore - the script degrades gracefully

## Development

### Testing Script Changes

```bash
# Test with sample input (in iTerm2)
echo '{"session_id": "test", "workspace": {"project_dir": "'"$PWD"'"}}' | \
  ./bin/statusline.sh
```

## Related Plugins

- **commit-skill** - Automatic git commit management

## Support

- **Issues**: [GitHub Issues](https://github.com/nsheaps/ai-mktpl/issues)
- **Documentation**: [Main README](../../README.md)

## License

MIT
