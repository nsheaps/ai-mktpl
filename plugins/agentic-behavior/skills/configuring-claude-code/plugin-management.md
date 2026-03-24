# Plugin Management Guide

Complete reference for finding, installing, configuring, and removing Claude Code plugins.

## Plugin ID Format

All plugin identifiers use the format: `<plugin-name>@<marketplace-name>`

Examples:

- `common-sense@ai-mktpl`
- `plugin-dev@claude-plugins-official`
- `mise@ai-mktpl`

## Finding Plugins

### Browse Available Plugins

```bash
# List all available plugins (JSON only)
claude plugins list --available --json

# Returns { "installed": [...], "available": [...] }
```

The `--available` flag requires `--json`. There is no human-readable browse mode.

Each available plugin entry includes: `pluginId`, `name`, `description`, `marketplaceName`, and `installCount`.

### List Configured Marketplaces

```bash
# Human-readable
claude plugins marketplace list

# JSON
claude plugins marketplace list --json
```

### List Installed Plugins

```bash
# Human-readable (shows version, scope, enabled status)
claude plugins list

# JSON (includes installPath, timestamps, projectPath)
claude plugins list --json
```

## Installing Plugins

### From a Marketplace

```bash
claude plugins install <plugin-name>@<marketplace> [--scope <scope>]
```

Alias: `claude plugins i`

### Scope Options

| Scope | Settings File | Default? | Use Case |
|-------|---------------|----------|----------|
| `user` | `~/.claude/settings.json` | Yes | Personal plugins, all projects |
| `project` | `.claude/settings.json` | No | Team-shared, committed to git |
| `local` | `.claude/settings.local.json` | No | Personal project overrides, gitignored |

### Examples

```bash
# Install for all projects (default: user scope)
claude plugins install common-sense@ai-mktpl

# Install for the team (project scope, committed to git)
claude plugins install common-sense@ai-mktpl --scope project

# Install just for you on this project (local, gitignored)
claude plugins install common-sense@ai-mktpl --scope local
```

### What Install Does

1. Downloads plugin from marketplace to `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`
2. Adds `"<plugin-id>": true` to `enabledPlugins` in the scope's settings file
3. Records metadata in `~/.claude/plugins/installed_plugins.json`

### Local Development (Not via Install)

Local paths cannot be installed via `claude plugins install`. For development, use the CLI flag:

```bash
# Load plugin from local directory (session only, not persisted)
claude --plugin-dir /path/to/my-plugin

# Multiple local plugins
claude --plugin-dir /path/to/plugin-a --plugin-dir /path/to/plugin-b
```

## Enabling and Disabling Plugins

Disabling keeps the plugin installed but inactive. Re-enabling is instant.

### Disable a Plugin

```bash
claude plugins disable <plugin-id> [--scope <scope>]
```

Sets the `enabledPlugins` entry to `false`:

```json
{ "enabledPlugins": { "my-plugin@marketplace": false } }
```

### Disable All Plugins

```bash
claude plugins disable --all
```

**Warning:** This sets ALL `enabledPlugins` entries to `false` across ALL scopes. Cannot be combined with `--scope`. You must individually re-enable each plugin after.

### Enable a Plugin

```bash
claude plugins enable <plugin-id> [--scope <scope>]
```

If `--scope` is omitted, auto-detects which settings file contains the plugin entry.

### Enable vs Install

- `enable` only works for plugins that are already installed (have an entry in `enabledPlugins`)
- `install` downloads and enables in one step
- After `disable`, use `enable` to reactivate without re-downloading

## Uninstalling Plugins

### Syntax

```bash
claude plugins uninstall <plugin-id> [--scope <scope>] [--keep-data]
```

Alias: `claude plugins remove`

### What Uninstall Does

1. **Removes** the key entirely from `enabledPlugins` (unlike `disable` which sets it to `false`)
2. Removes the entry from `~/.claude/plugins/installed_plugins.json`
3. Cache files in `~/.claude/plugins/cache/` may remain

### Preserving Plugin Data

```bash
claude plugins uninstall <plugin-id> --keep-data
```

Preserves the plugin's persistent data at `~/.claude/plugins/data/<id>/`.

### Disable vs Uninstall

| Action | `enabledPlugins` | Can re-enable? | Needs re-install? |
|--------|------------------|----------------|-------------------|
| `disable` | Set to `false` | Yes, instant | No |
| `uninstall` | Key removed | No | Yes |

## Updating Plugins

```bash
# Update a specific plugin
claude plugins update <plugin-id> [--scope <scope>]

# Refresh marketplace metadata
claude plugins marketplace update [name]
```

A session restart is required after updating for changes to take effect.

## Marketplace Management

### Adding a Marketplace

```bash
# From GitHub repo
claude plugins marketplace add <org/repo> [--scope <scope>]

# For monorepos, limit to specific directories
claude plugins marketplace add <org/repo> --sparse .claude-plugin plugins
```

### Sharing Marketplaces with Your Team

Add `extraKnownMarketplaces` to `.claude/settings.json` (committed to git):

```json
{
  "extraKnownMarketplaces": {
    "my-marketplace": {
      "source": { "source": "github", "repo": "my-org/my-marketplace" }
    }
  }
}
```

Team members get the marketplace automatically — no manual `marketplace add` needed.

### Removing a Marketplace

```bash
claude plugins marketplace remove <name>
```

### Updating Marketplace Metadata

```bash
# Update specific marketplace
claude plugins marketplace update ai-mktpl

# Update all
claude plugins marketplace update
```

## Settings in `enabledPlugins`

The `enabledPlugins` key is an object in settings files at each scope:

```json
{
  "enabledPlugins": {
    "plugin-a@marketplace": true,
    "plugin-b@marketplace": false,
    "plugin-c@marketplace": true
  }
}
```

- `true` — installed and enabled
- `false` — installed but disabled
- Key absent — not installed at this scope

### Scope Override Behavior

Settings merge across scopes. When a plugin appears in multiple scopes:

- **Local** overrides **project** overrides **user**
- A plugin `true` at project scope but `false` at local scope is **disabled**
- A plugin `true` at user scope and absent at project scope is **enabled**

## File System Layout

```
~/.claude/plugins/
├── cache/                              # Downloaded plugin files
│   ├── ai-mktpl/
│   │   ├── common-sense/1.3.12/       # Plugin at specific version
│   │   └── mise/0.2.16/
│   └── claude-plugins-official/
│       └── plugin-dev/79caa0d824ac/
├── installed_plugins.json              # Installation metadata
├── known_marketplaces.json             # Marketplace registry
└── marketplaces/                       # Marketplace repo clones
    ├── ai-mktpl/
    └── claude-plugins-official/
```

## Validating Plugins

```bash
claude plugins validate /path/to/plugin
```

Validates the plugin manifest at `.claude-plugin/plugin.json` and reports any issues.

## Common Workflows

### Set Up a Project for Team Use

```bash
# Add marketplace to project settings
claude plugins marketplace add my-org/plugins --scope project

# Install shared plugins
claude plugins install linter@my-org-plugins --scope project
claude plugins install formatter@my-org-plugins --scope project

# Commit .claude/settings.json so teammates get the same plugins
git add .claude/settings.json && git commit -m "Add team plugins"
```

### Try a Plugin Without Committing

```bash
# Install at local scope (gitignored)
claude plugins install experimental@marketplace --scope local
```

### Temporarily Disable a Noisy Plugin

```bash
claude plugins disable noisy-plugin@marketplace
# Later...
claude plugins enable noisy-plugin@marketplace
```
