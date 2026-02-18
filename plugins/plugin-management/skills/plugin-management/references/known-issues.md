# Known Issues — Plugin Management

Active bugs and workarounds related to plugin installation, updates, and lifecycle management.

## Hook Paths After Plugin Update (#18517)

**Issue**: [github.com/anthropics/claude-code/issues/18517](https://github.com/anthropics/claude-code/issues/18517)

**Symptom**: After updating a plugin, hooks stop firing. The `${CLAUDE_PLUGIN_ROOT}` variable
in `settings.json` retains the old versioned cache path (e.g., `~/.claude/plugins/cache/old-hash/`)
instead of pointing to the new version.

**Root cause**: Plugin updates create a new cache directory with a new hash. The settings.json
entry referencing `${CLAUDE_PLUGIN_ROOT}` resolves to the old path.

**Workaround**:
1. Uninstall and reinstall the plugin
2. Or manually update the path in settings.json
3. Restart Claude Code after the change

**Status**: Open, no fix timeline announced.

## CLAUDE.md Not Reloaded After Compaction (#22085)

**Issue**: [github.com/anthropics/claude-code/issues/22085](https://github.com/anthropics/claude-code/issues/22085)

**Symptom**: After context compaction, CLAUDE.md content may not be refreshed from disk.
Changes made to CLAUDE.md during a long session may not take effect after compaction.

**Workaround**: Run `/clear` after compaction to force a full reload.

**Status**: Open.

## Hook Configuration Hot-Reload (#22679)

**Issue**: [github.com/anthropics/claude-code/issues/22679](https://github.com/anthropics/claude-code/issues/22679)

**Symptom**: Changes to hook configurations in settings.json may not take effect without
a restart, despite settings.json being file-watched.

**Root cause**: While the settings file change is detected, the hook registration system
may not re-process the new configuration.

**Workaround**: Restart Claude Code after changing hook configurations.

**Status**: Open.

## MCP Server Hot-Reload Requested (#24057)

**Issue**: [github.com/anthropics/claude-code/issues/24057](https://github.com/anthropics/claude-code/issues/24057)

**Symptom**: Adding, removing, or modifying MCP server configurations requires a full
restart of Claude Code. Server connections are established at startup only.

**Impact**: During plugin development that includes MCP servers, every config change
requires restarting the session.

**Workaround**: No workaround — must restart.

**Status**: Open, feature request.

## Delegate Mode Permission Inheritance (#25037)

**Issue**: [github.com/anthropics/claude-code/issues/25037](https://github.com/anthropics/claude-code/issues/25037)

**Symptom**: In agent team sessions, teammates inherit delegate mode restrictions
incorrectly, preventing them from using tools they should have access to.

**Impact**: Affects plugin behavior in multi-agent team sessions where the lead uses
`--permission-mode delegate`.

**Workaround**: Use `--dangerously-skip-permissions` for teammates instead of delegate mode.

**Status**: Open.

## General Troubleshooting Checklist

When a plugin isn't behaving as expected:

1. **Check `/plugin` errors tab** — Shows load failures with error messages
2. **Run `claude plugin validate`** — Verifies manifest structure
3. **Check the cache** — `ls ~/.claude/plugins/cache/` to see installed plugins
4. **Verify settings** — Ensure `enabledPlugins` array includes the correct plugin@marketplace entry
5. **Try `/clear`** — Forces memoized caches to refresh (skills, rules, CLAUDE.md)
6. **Restart as last resort** — Fixes MCP, plugin code, agent file, and hook config issues
7. **Check `--debug` output** — `claude --debug` shows plugin loading diagnostics
