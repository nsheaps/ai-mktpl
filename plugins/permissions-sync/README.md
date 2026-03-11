# permissions-sync

Merge permission scopes from configurable source `settings.json` files into `settings.local.json` on session start.

## Features

- **Multi-source merging**: Combine permissions from multiple settings files
- **GitHub repo support**: Fetch settings directly from GitHub repositories
- **Local file support**: Read from project or user-level settings files
- **Union or replace strategy**: Deduplicated merge or last-wins replacement
- **Selective sync**: Choose which categories (allow, deny, ask) to sync
- **Project or user targeting**: Write to project-level or user-level settings.local.json

## How It Works

On session start:

1. Reads configured source list from `plugins.settings.yaml`
2. For each source, extracts the `permissions` key:
   - **Local files**: Reads directly from the filesystem
   - **GitHub references**: Fetches via `gh api` (or raw GitHub API fallback)
3. Merges permissions using the configured strategy (union or replace)
4. Writes merged permissions to `settings.local.json` using atomic safe-write

## Configuration

```yaml
# In $CLAUDE_PROJECT_DIR/.claude/plugins.settings.yaml
# or ~/.claude/plugins.settings.yaml

permissions-sync:
  enabled: true

  # Where to write: "project" or "user"
  target: "project"

  # Sources to merge (in order)
  sources:
    - "github:nsheaps/cept:.claude/settings.json"
    - "$HOME/.claude/settings.json"
    # - "github:myorg/shared-config:.claude/settings.json"

  # Which categories to sync
  syncAllow: true
  syncDeny: true
  syncAsk: true

  # Merge strategy: "union" (combine all) or "replace" (last source wins)
  strategy: "union"
```

### Source Formats

**GitHub repository reference:**

```
github:owner/repo:path/to/settings.json
```

Uses `gh api` to fetch the file contents. Requires `gh` to be authenticated.

**Local file path:**

```
$CLAUDE_PROJECT_DIR/.claude/settings.json
$HOME/.claude/settings.json
~/other-project/.claude/settings.json
```

Supports `$HOME`, `$CLAUDE_PROJECT_DIR`, and `~` expansion.

## Installation Modes

### Project-Level Installation

Install the plugin in a specific project. Permissions sync to that project's `settings.local.json`.

```yaml
permissions-sync:
  target: "project"
  sources:
    - "github:myorg/shared-config:.claude/settings.json"
```

### User-Level Installation

Install the plugin in your user config (`~/.claude/`). Permissions sync to your user-level `settings.local.json`.

```yaml
permissions-sync:
  target: "user"
  sources:
    - "github:myorg/shared-config:.claude/settings.json"
```

## Merge Strategies

### Union (default)

Combines all permission arrays from all sources, deduplicating entries:

```
Source 1: allow: ["Bash(git:*)", "Glob"]
Source 2: allow: ["Bash(npm:*)", "Glob"]
Result:   allow: ["Bash(git:*)", "Bash(npm:*)", "Glob"]
```

### Replace

Last source wins for each permission category:

```
Source 1: allow: ["Bash(git:*)"]
Source 2: allow: ["Bash(npm:*)"]
Result:   allow: ["Bash(npm:*)"]
```

## Requirements

- `jq` must be available (used for JSON manipulation)
- `yq` recommended for YAML config reading (grep fallback for simple cases)
- `gh` recommended for GitHub source fetching (curl fallback available)

## How settings.local.json Works

Claude Code merges `settings.local.json` on top of `settings.json` at runtime.
This plugin writes only to `settings.local.json` to avoid modifying the
version-controlled `settings.json`. The `.claude/settings.local.json` file
is already in `.gitignore` by convention.
