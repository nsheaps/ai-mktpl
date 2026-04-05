# Plugin Update Checker Plugin

**Status:** Draft
**Priority:** Medium

## Problem Statement

Claude Code plugins are installed from marketplaces and cached locally at `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`. When a marketplace updates (e.g., after a `git pull` or remote fetch), the cached version may be stale. Currently there is no mechanism to:

- Notify the user that newer plugin versions are available
- Compare installed/cached versions against marketplace versions
- Prompt or automate plugin cache refresh

Users must manually check marketplace.json or rely on Claude Code's internal resolution, which may not surface version drift clearly.

## Solution

A Claude Code plugin that compares cached plugin versions against marketplace declarations and reports which plugins have updates available. Runs on session start and optionally on demand via a slash command.

## Technical Design

### Data Sources

1. **Marketplace versions** - Read from marketplace.json files. For directory-type marketplaces, read directly from the filesystem path. Location of registered marketplaces is in `~/.claude/settings.json` under `extraKnownMarketplaces`.

2. **Cached versions** - Scan `~/.claude/plugins/cache/<marketplace>/<plugin>/` directories. Each subdirectory name is a version string. The highest semver is the "installed" version.

3. **Enabled plugins** - Read from `~/.claude/settings.json` and project-level `.claude/settings.json` under `enabledPlugins` (format: `<plugin>@<marketplace>`).

### Hook: SessionStart

On session start, compare versions for all enabled plugins:

```bash
#!/usr/bin/env bash
# For each enabled plugin, compare cached vs marketplace version
SETTINGS="$HOME/.claude/settings.json"
CACHE_DIR="$HOME/.claude/plugins/cache"

# Parse enabled plugins from settings
# Format: "plugin-name@marketplace-name": true
enabled=$(jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$SETTINGS")

updates_available=""
for entry in $enabled; do
  plugin="${entry%%@*}"
  marketplace="${entry##*@}"

  # Get marketplace version from marketplace.json
  marketplace_json=$(resolve_marketplace_path "$marketplace")
  marketplace_version=$(jq -r --arg name "$plugin" '.plugins[] | select(.name == $name) | .version' "$marketplace_json")

  # Get cached version (highest semver dir)
  cached_version=$(ls "$CACHE_DIR/$marketplace/$plugin/" 2>/dev/null | sort -V | tail -1)

  if [ "$marketplace_version" != "$cached_version" ] && [ -n "$marketplace_version" ]; then
    updates_available="${updates_available}${plugin}: ${cached_version:-none} -> ${marketplace_version}\n"
  fi
done

if [ -n "$updates_available" ]; then
  echo "Plugin updates available:"
  printf '%b' "$updates_available"
fi
```

### Slash Command: `/check-plugin-updates`

On-demand version check that shows a detailed table of all plugins with their cached vs marketplace versions.

### Resolving Marketplace Paths

Marketplaces can be:

- **directory**: `source.path` points to a local directory containing `.claude-plugin/marketplace.json`
- **github**: `source.repo` points to a GitHub repo; fetch marketplace.json via `gh api` or raw URL

The plugin should handle both source types.

## Plugin Structure

```
plugins/plugin-update-checker/
  .claude-plugin/
    plugin.json
  hooks/
    hooks.json
    check-updates.sh        # SessionStart hook
  commands/
    check-plugin-updates.md # Slash command for on-demand check
  skills/
    plugin-update-checker/
      SKILL.md
  README.md
```

## MVP Scope

1. **SessionStart hook** that compares enabled plugin versions (cached vs marketplace)
2. **Directory marketplace support only** (local filesystem)
3. **Simple text output** listing plugins with available updates
4. **No auto-update** - just notification

## Future Enhancements

- GitHub marketplace source support (fetch remote marketplace.json)
- Auto-update option (re-cache plugins from marketplace source)
- Configurable check frequency (every session, daily, weekly)
- Integration with statusline plugin to show update count
- `just` recipe for bulk-updating all plugins locally
- Notification when a plugin update includes breaking changes (major version bump)

## References

- [Claude Code Plugins Documentation](https://code.claude.com/docs/en/plugins)
- Plugin cache location: `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`
- Marketplace registration: `~/.claude/settings.json` under `extraKnownMarketplaces`
- Enabled plugins: `~/.claude/settings.json` under `enabledPlugins`
- CD pipeline that bumps versions: `.github/workflows/cd.yaml`
