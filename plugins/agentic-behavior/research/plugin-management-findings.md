# Claude Code Plugin Management - CLI Research Findings

**Date:** 2026-03-24
**Claude Code Version:** Tested on current Claude Code CLI

## Table of Contents

1. [CLI Command Structure](#cli-command-structure)
2. [Finding Plugins](#finding-plugins)
3. [Installing Plugins](#installing-plugins)
4. [Listing Installed Plugins](#listing-installed-plugins)
5. [Enabling and Disabling Plugins](#enabling-and-disabling-plugins)
6. [Uninstalling Plugins](#uninstalling-plugins)
7. [Updating Plugins](#updating-plugins)
8. [Marketplace Management](#marketplace-management)
9. [Plugin Validation](#plugin-validation)
10. [Settings File Structure](#settings-file-structure)
11. [File System Layout](#file-system-layout)
12. [Local Development](#local-development)
13. [Key Findings and Gotchas](#key-findings-and-gotchas)

---

## CLI Command Structure

The top-level command is `claude plugins` (or `claude plugin` -- both work as aliases).

```
claude plugins --help
```

**Output:**

```
Usage: claude plugin|plugins [options] [command]

Manage Claude Code plugins

Commands:
  disable [options] [plugin]           Disable an enabled plugin
  enable [options] <plugin>            Enable a disabled plugin
  install|i [options] <plugin>         Install a plugin from available marketplaces
  list [options]                       List installed plugins
  marketplace                          Manage Claude Code marketplaces
  uninstall|remove [options] <plugin>  Uninstall an installed plugin
  update [options] <plugin>            Update a plugin to the latest version
  validate [options] <path>            Validate a plugin or marketplace manifest
```

---

## Finding Plugins

### Browse Available Plugins

```bash
claude plugins list --available --json
```

This returns JSON with two top-level keys: `installed` and `available`. The `--available` flag **requires** `--json`.

Each available plugin entry includes:

- `pluginId` - Format: `<name>@<marketplace>` (e.g., `common-sense@ai-mktpl`)
- `name` - Plugin name
- `marketplace` - Marketplace name
- `version` - Latest version
- `description` - Plugin description
- Additional metadata fields

### Plugin ID Format

Plugin identifiers always use the format: `<plugin-name>@<marketplace-name>`

Examples:

- `common-sense@ai-mktpl`
- `plugin-dev@claude-plugins-official`
- `mise@ai-mktpl`

### List Configured Marketplaces

```bash
claude plugins marketplace list
```

**Output:**

```
Configured marketplaces:

  > claude-plugins-official
    Source: GitHub (anthropics/claude-plugins-official)

  > ai-mktpl
    Source: GitHub (nsheaps/ai-mktpl)
```

JSON format also available:

```bash
claude plugins marketplace list --json
```

**Output:**

```json
[
  {
    "name": "ai-mktpl",
    "source": "github",
    "repo": "nsheaps/ai-mktpl",
    "installLocation": "/root/.claude/plugins/marketplaces/ai-mktpl"
  },
  {
    "name": "claude-plugins-official",
    "source": "github",
    "repo": "anthropics/claude-plugins-official",
    "installLocation": "/root/.claude/plugins/marketplaces/claude-plugins-official"
  }
]
```

---

## Installing Plugins

### Syntax

```bash
claude plugins install <plugin-name>@<marketplace> [--scope <scope>]
```

Alias: `claude plugins i`

### Scope Options

| Scope            | Settings File                 | Description                         |
| ---------------- | ----------------------------- | ----------------------------------- |
| `user` (default) | `~/.claude/settings.json`     | Available in all projects           |
| `project`        | `.claude/settings.json`       | Shared with team (checked into git) |
| `local`          | `.claude/settings.local.json` | Project-specific, not checked in    |

### Examples Tested

**Install at project scope:**

```bash
$ claude plugins install agent-tab-titles@ai-mktpl --scope project
Installing plugin "agent-tab-titles@ai-mktpl"...
√ Successfully installed plugin: agent-tab-titles@ai-mktpl (scope: project)
```

**Install at user scope:**

```bash
$ claude plugins install agent-tab-titles@ai-mktpl --scope user
Installing plugin "agent-tab-titles@ai-mktpl"...
√ Successfully installed plugin: agent-tab-titles@ai-mktpl (scope: user)
```

**Install at local scope:**

```bash
$ claude plugins install agent-tab-titles@ai-mktpl --scope local
Installing plugin "agent-tab-titles@ai-mktpl"...
√ Successfully installed plugin: agent-tab-titles@ai-mktpl (scope: local)
```

### What Install Does

1. Downloads plugin from marketplace cache to `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`
2. Adds `"<plugin>@<marketplace>": true` to the `enabledPlugins` key in the appropriate settings file
3. Records installation metadata in `~/.claude/plugins/installed_plugins.json`

### Local Path Install

**Local paths are NOT supported via `install`.** Attempting:

```bash
$ claude plugins install /home/user/ai-mktpl/plugins/agent-tab-titles --scope project
× Failed to install plugin "...": Plugin "..." not found in any configured marketplace
```

For local development, use the `--plugin-dir` CLI flag instead (see [Local Development](#local-development)).

---

## Listing Installed Plugins

### Human-Readable Format

```bash
claude plugins list
```

**Output:**

```
Installed plugins:

  > common-sense@ai-mktpl
    Version: 1.3.12
    Scope: project
    Status: √ enabled

  > git-spice@ai-mktpl
    Version: 0.2.6
    Scope: project
    Status: √ enabled

  > mise@ai-mktpl
    Version: 0.2.16
    Scope: project
    Status: √ enabled

  > plugin-dev@claude-plugins-official
    Version: 79caa0d824ac
    Scope: project
    Status: √ enabled

  > web-auto-approve@ai-mktpl
    Version: 0.1.0
    Scope: project
    Status: √ enabled
```

### JSON Format

```bash
claude plugins list --json
```

Each entry includes:

```json
{
  "id": "common-sense@ai-mktpl",
  "version": "1.3.12",
  "scope": "project",
  "enabled": true,
  "installPath": "/root/.claude/plugins/cache/ai-mktpl/common-sense/1.3.12",
  "installedAt": "2026-03-24T19:14:23.356Z",
  "lastUpdated": "2026-03-24T19:14:23.356Z",
  "projectPath": "/home/user/ai-mktpl"
}
```

### Including Available (Not Installed) Plugins

```bash
claude plugins list --available --json
```

Returns both `installed` and `available` arrays. The `--available` flag requires `--json`.

---

## Enabling and Disabling Plugins

### Disable a Specific Plugin

```bash
claude plugins disable <plugin-id> [--scope <scope>]
```

**Example:**

```bash
$ claude plugins disable agent-tab-titles@ai-mktpl
√ Successfully disabled plugin: agent-tab-titles (scope: project)
```

This sets the value to `false` in `enabledPlugins`:

```json
{
  "enabledPlugins": {
    "agent-tab-titles@ai-mktpl": false
  }
}
```

The plugin remains installed but inactive. It still appears in `claude plugins list` with `Status: x disabled`.

### Disable All Plugins

```bash
claude plugins disable --all
```

**Output:**

```
√ Disabled 8 plugins
```

**WARNING:** `--all` cannot be combined with `--scope`. It sets ALL entries in `enabledPlugins` to `false` across all scopes, including plugins that are referenced but not currently installed (e.g., plugins set to `false` that were previously uninstalled). This is a broad operation.

### Enable a Plugin

```bash
claude plugins enable <plugin-id> [--scope <scope>]
```

**Example:**

```bash
$ claude plugins enable agent-tab-titles@ai-mktpl
√ Successfully enabled plugin: agent-tab-titles (scope: project)
```

Scope auto-detection: If `--scope` is not provided, the CLI detects which settings file contains the plugin entry and updates that one.

### Key Behavior: Disable Without Uninstall

You **can** disable a plugin without uninstalling it. The plugin files remain in the cache at `~/.claude/plugins/cache/`, and the `enabledPlugins` entry is set to `false`. Re-enabling is instant since no re-download is needed.

---

## Uninstalling Plugins

### Syntax

```bash
claude plugins uninstall <plugin-id> [--scope <scope>] [--keep-data]
```

Alias: `claude plugins remove`

### Example

```bash
$ claude plugins uninstall agent-tab-titles@ai-mktpl --scope project
√ Successfully uninstalled plugin: agent-tab-titles (scope: project)
```

### What Uninstall Does

1. Removes the plugin entry from `enabledPlugins` in the settings file (key is fully deleted, not set to false)
2. Removes the entry from `~/.claude/plugins/installed_plugins.json`
3. Plugin cache files may remain in `~/.claude/plugins/cache/`

### The `--keep-data` Flag

```bash
claude plugins uninstall <plugin> --keep-data
```

Preserves the plugin's persistent data directory at `~/.claude/plugins/data/{id}/`. Without this flag, that data directory is also removed.

---

## Updating Plugins

### Syntax

```bash
claude plugins update <plugin-id> [--scope <scope>]
```

Scope options: `user`, `project`, `local`, `managed`

Updates a plugin to the latest version available in its marketplace. A session restart is required for the update to take effect.

### Marketplace Refresh

To pull latest marketplace metadata:

```bash
$ claude plugins marketplace update ai-mktpl
Updating marketplace: ai-mktpl...
Refreshing marketplace cache (timeout: 120s)...
√ Successfully updated marketplace: ai-mktpl
```

Update all marketplaces:

```bash
claude plugins marketplace update
```

---

## Marketplace Management

### Adding a Marketplace

```bash
claude plugins marketplace add <source> [--scope <scope>] [--sparse <paths...>]
```

Source can be:

- A GitHub repo (e.g., `nsheaps/ai-mktpl`)
- A URL
- A local path

**Scope:** `user` (default), `project`, or `local`

**Sparse checkout:** For monorepos, limit checkout to specific directories:

```bash
claude plugins marketplace add my-org/monorepo --sparse .claude-plugin plugins
```

### Removing a Marketplace

```bash
claude plugins marketplace remove <name>
```

Alias: `claude plugins marketplace rm`

### Updating Marketplaces

```bash
# Update specific marketplace
claude plugins marketplace update <name>

# Update all
claude plugins marketplace update
```

### Where Marketplaces Are Declared

Marketplaces are stored in two locations:

1. **Known marketplaces file:** `~/.claude/plugins/known_marketplaces.json`

   ```json
   {
     "ai-mktpl": {
       "source": { "source": "github", "repo": "nsheaps/ai-mktpl" },
       "installLocation": "/root/.claude/plugins/marketplaces/ai-mktpl",
       "lastUpdated": "2026-03-24T19:09:04.600Z"
     }
   }
   ```

2. **Settings files** via `extraKnownMarketplaces`:
   ```json
   {
     "extraKnownMarketplaces": {
       "ai-mktpl": {
         "source": { "source": "github", "repo": "nsheaps/ai-mktpl" }
       }
     }
   }
   ```

The `extraKnownMarketplaces` key in settings files ensures teammates can share marketplace configuration via the project's `.claude/settings.json`.

---

## Plugin Validation

### Syntax

```bash
claude plugins validate <path>
```

Validates a plugin manifest or marketplace manifest at the given path.

### Example

```bash
$ claude plugins validate /home/user/ai-mktpl/plugins/common-sense
Validating plugin manifest: /home/user/ai-mktpl/plugins/common-sense/.claude-plugin/plugin.json

√ Validation passed
```

---

## Settings File Structure

### The `enabledPlugins` Key

The `enabledPlugins` key is an object mapping plugin IDs to booleans.

```json
{
  "enabledPlugins": {
    "plugin-dev@claude-plugins-official": true,
    "common-sense@ai-mktpl": true,
    "git-spice@ai-mktpl": true,
    "mise@ai-mktpl": true,
    "web-auto-approve@ai-mktpl": true,
    "1pass@ai-mktpl": false,
    "sequential-thinking@ai-mktpl": false
  }
}
```

- `true` = installed and enabled
- `false` = installed but disabled (or was previously installed/referenced)
- Key absent = not installed at this scope

### Settings File Hierarchy

| File                          | Scope   | Checked into git? |
| ----------------------------- | ------- | ----------------- |
| `~/.claude/settings.json`     | User    | N/A (user home)   |
| `.claude/settings.json`       | Project | Yes               |
| `.claude/settings.local.json` | Local   | No (gitignored)   |

Settings are merged. A plugin enabled at any scope is available. Local settings can override project settings.

### Example: Project-Level Settings (`.claude/settings.json`)

```json
{
  "enabledPlugins": {
    "plugin-dev@claude-plugins-official": true,
    "common-sense@ai-mktpl": true,
    "git-spice@ai-mktpl": true,
    "mise@ai-mktpl": true,
    "web-auto-approve@ai-mktpl": true,
    "edit-utils@ai-mktpl": true,
    "scm-utils@ai-mktpl": true
  },
  "extraKnownMarketplaces": {
    "claude-plugins-official": {
      "source": { "source": "github", "repo": "anthropics/claude-plugins-official" }
    },
    "ai-mktpl": {
      "source": { "source": "github", "repo": "nsheaps/ai-mktpl" }
    }
  }
}
```

### Example: User-Level Settings (`~/.claude/settings.json`)

After installing at user scope:

```json
{
  "enabledPlugins": {
    "agent-tab-titles@ai-mktpl": true
  }
}
```

### Example: Local Settings (`.claude/settings.local.json`)

After installing at local scope:

```json
{
  "enabledPlugins": {
    "agent-tab-titles@ai-mktpl": true
  }
}
```

After uninstalling, the file retains the structure but with empty object:

```json
{
  "enabledPlugins": {}
}
```

---

## File System Layout

### Plugin Installation Cache

```
~/.claude/plugins/
├── blocklist.json                          # Blocked plugins
├── cache/                                  # Installed plugin files
│   ├── ai-mktpl/
│   │   ├── common-sense/1.3.12/           # Plugin files at specific version
│   │   ├── git-spice/0.2.6/
│   │   └── mise/0.2.16/
│   └── claude-plugins-official/
│       └── plugin-dev/79caa0d824ac/
├── install-counts-cache.json               # Popularity data
├── installed_plugins.json                  # Installation metadata
├── known_marketplaces.json                 # Marketplace registry
└── marketplaces/                           # Full marketplace clones
    ├── ai-mktpl/                           # Git checkout of marketplace repo
    └── claude-plugins-official/
```

### installed_plugins.json Structure

```json
{
  "version": 2,
  "plugins": {
    "common-sense@ai-mktpl": [
      {
        "scope": "project",
        "projectPath": "/home/user/ai-mktpl",
        "installPath": "/root/.claude/plugins/cache/ai-mktpl/common-sense/1.3.12",
        "version": "1.3.12",
        "installedAt": "2026-03-24T19:14:23.356Z",
        "lastUpdated": "2026-03-24T19:14:23.356Z",
        "gitCommitSha": "34451149eef7707596104539db5efc2bc57c5213"
      }
    ]
  }
}
```

A plugin can have multiple entries (e.g., installed at user scope AND project scope for different projects).

---

## Local Development

### `--plugin-dir` Flag

For loading plugins from a local directory during development (not from a marketplace):

```bash
claude --plugin-dir /path/to/my-plugin
```

This loads the plugin for the current session only. It does not modify any settings files. Multiple directories can be specified:

```bash
claude --plugin-dir /path/to/plugin-a --plugin-dir /path/to/plugin-b
```

### Key Difference from `install`

- `install` only works with marketplace plugins (not local paths)
- `--plugin-dir` is a session-level flag that loads from the filesystem directly
- `--plugin-dir` does not persist between sessions (not saved to settings)

---

## Key Findings and Gotchas

### 1. `disable --all` Is Broad and Destructive

`claude plugins disable --all` sets ALL `enabledPlugins` entries to `false` across ALL scopes. This includes:

- Plugins that were already `false` (no-op for those)
- Plugins referenced in settings but not currently installed
- Plugins at every scope (user, project, local)

It **cannot** be combined with `--scope`. After running it, you must individually re-enable each plugin you want.

### 2. Uninstall Removes the Key; Disable Sets It to False

- `disable`: `"my-plugin@marketplace": false` (key remains)
- `uninstall`: key is removed entirely from `enabledPlugins`

### 3. Install Default Scope Is User

If you don't specify `--scope`, install defaults to `user` scope (`~/.claude/settings.json`). For team-shared plugins, always use `--scope project`.

### 4. Local Path Install Is Not Supported

`claude plugins install /local/path` does not work. Use `--plugin-dir` for local development.

### 5. Marketplace Configuration Is Shared via Settings

The `extraKnownMarketplaces` key in `.claude/settings.json` ensures all team members have access to the same marketplaces without manual `marketplace add` commands.

### 6. Plugin Versions from Official Marketplace Use Git SHAs

Plugins from `claude-plugins-official` use git commit SHAs as version numbers (e.g., `79caa0d824ac`), while custom marketplaces like `ai-mktpl` use semver (e.g., `1.3.12`).

### 7. `--available` Requires `--json`

You cannot list available plugins in human-readable format. The `--available` flag only works with `--json`.

### 8. Settings Merge Behavior

Plugins enabled at any scope are active. If a plugin is `true` at project scope and `false` at local scope, the local scope overrides (local > project > user for the same key).

### 9. Marketplace Sparse Checkout

For monorepos, `marketplace add` supports `--sparse` to only checkout specific directories, reducing clone size.

### 10. Session Restart Required After Update

`claude plugins update` downloads the new version but requires a session restart to apply changes.
