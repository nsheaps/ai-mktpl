---
name: plugin-management
description: >
  This skill should be used when the user asks to "install a plugin", "update a plugin",
  "remove a plugin", "check if a plugin is loaded", "reload plugins", "why isn't my plugin working",
  "what needs a restart", "hot reload", "plugin cache", "plugin settings", "enable a plugin",
  "disable a plugin", "validate a plugin", or mentions plugin installation, updates, troubleshooting,
  or lifecycle management in Claude Code.
version: 0.1.0
---

# Plugin Installation and Management

Guide for installing, updating, verifying, and troubleshooting Claude Code plugins. Covers what
hot-reloads, what requires a restart, and common failure modes.

## Installation Methods

### Method 1: Marketplace (Recommended)

Install from a configured marketplace:

```
/plugin install plugin-name@marketplace-name
```

Scopes control where the plugin entry is stored:

| Scope | Settings File | Persists For |
|-------|--------------|--------------|
| `user` | `~/.claude/settings.json` | All projects for this user |
| `project` | `.claude/settings.json` (repo root) | All users of this project |
| `local` | `.claude/settings.local.json` | This user in this project only |

The plugin is downloaded and cached at `~/.claude/plugins/cache/`.

### Method 2: Plugin Directory (Development/Testing)

Load a local plugin for the current session only:

```bash
claude --plugin-dir /path/to/my-plugin
```

This does **not** persist — the plugin is only available for that session. Use this during plugin
development to test changes. A restart is required to pick up code changes even with `--plugin-dir`.

### Method 3: Team Configuration

Add marketplaces and plugins in settings files:

```json
{
  "extraKnownMarketplaces": ["nsheaps/ai-mktpl"],
  "enabledPlugins": ["plugin-name@nsheaps/ai-mktpl"]
}
```

This can go in user, project, or local settings depending on desired scope.

## Updating Plugins

Plugin updates are fetched when Claude Code starts or when explicitly triggered:

1. **Automatic**: Claude Code checks for updates on session start
2. **Manual**: Run `/plugin` and use the UI to check for updates
3. **Force reinstall**: Uninstall and reinstall to get the latest version

After an update, the cached copy at `~/.claude/plugins/cache/` is replaced.

**Known issue**: After a plugin update, `${CLAUDE_PLUGIN_ROOT}` in `settings.json` may retain the
old versioned cache path, causing hook failures. See `references/known-issues.md` for the workaround.

## What Requires a Restart vs What Hot-Reloads

This is the most critical knowledge for plugin management. The rule is simple:

> **Only `settings.json` files are truly file-watched.** Everything else uses memoized caching
> that clears at lifecycle boundaries (`/clear`, `/compact`, plugin operations).

### Quick Reference

| Component | Hot-Reloads? | Notes |
|-----------|-------------|-------|
| `settings.json` changes | Immediate | Chokidar file watcher + event bus |
| Plugin install/uninstall | Immediate (v2.1.45+) | Cache invalidation on install |
| Plugin enable/disable | Immediate | Settings change triggers cache clear |
| Skills (SKILL.md content) | On `/clear` or `/compact` | Memoized, not file-watched |
| CLAUDE.md / rules files | On `/clear` or `/compact` | Same memoization pattern |
| Hook configs | On plugin reload | Cleared when plugin cache invalidated |
| MCP server configs | **Restart required** | Not file-watched, connections persist |
| Plugin code/manifest | **Restart required** | Cached at install time |
| `--plugin-dir` code changes | **Restart required** | Explicitly documented |
| Agent file changes | **Restart required** | Not watched |

For the full breakdown with source references, see `references/reload-behavior.md`.

### Practical Implications

- **Editing a SKILL.md?** Run `/clear` to pick up changes.
- **Changed a hook script?** The script itself runs fresh each time (it's a file on disk), but
  hook *configuration* (which hooks fire on which events) requires a plugin reload or restart.
- **Added an MCP server?** Must restart Claude Code.
- **Changed `settings.json`?** Takes effect immediately.

## Verifying Plugin Status

### Check Installed Plugins

```
/plugin
```

The plugin UI shows:
- **Installed tab**: All loaded plugins with version and source
- **Errors tab**: Plugins that failed to load (manifest issues, missing files)

### Debug Mode

```bash
claude --debug
# or within a session:
/debug
```

Shows plugin loading diagnostics including load order and any failures.

### Validate Plugin Structure

```bash
claude plugin validate /path/to/plugin
```

Checks the plugin manifest (`plugin.json`) for structural correctness.

### Verify Skills Loaded

```
/help
```

Plugin skills appear as `/plugin-name:skill-name` in the help output. If a skill is missing,
the plugin may have failed to load — check `/plugin` errors tab.

## Removing Plugins

### Uninstall

```
/plugin
```

Use the plugin UI to uninstall. This removes the entry from the relevant settings file and
clears the cached copy.

### Manual Removal

Remove the plugin entry from the appropriate settings file (`enabledPlugins` array) and
optionally delete the cache at `~/.claude/plugins/cache/<plugin-hash>/`.

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Plugin not appearing in `/plugin` | Not in `enabledPlugins` or marketplace not configured | Check settings files for correct entries |
| Skill not triggering | SKILL.md loaded before latest change | Run `/clear` to refresh memoized cache |
| Hook not firing after update | `${CLAUDE_PLUGIN_ROOT}` pointing to old path | See `references/known-issues.md` |
| MCP server not connecting | Config not reloaded | Restart Claude Code |
| "Plugin failed to load" error | Invalid `plugin.json` manifest | Run `claude plugin validate` |
| Plugin works with `--plugin-dir` but not installed | Cache stale or settings misconfigured | Uninstall, reinstall, restart |

## Additional Resources

### Reference Files

- **`references/reload-behavior.md`** — Detailed hot-reload matrix with source code references and
  GitHub issue links for each component
- **`references/known-issues.md`** — Known bugs, workarounds, and upstream issue tracking links

### Related Skills

- **`plugin-dev:plugin-structure`** — Creating new plugins (directory layout, manifest, components)
- **`plugin-dev:skill-development`** — Writing effective skills for plugins
- **`plugin-dev:hook-development`** — Creating and testing plugin hooks
- **`plugin-dev:mcp-integration`** — Configuring MCP servers in plugins
