# edit-utils

File editing utilities: auto-formatting and linting for written/edited files with project-aware configuration.

## How It Works

A **PostToolUse hook** runs after every `Write` or `Edit` tool call. If a formatter is configured, it formats the file in-place. No permission decision is made — the hook is purely advisory.

## Configuration

Configure via `plugins.settings.yaml` (project or user level):

```yaml
edit-utils:
  enabled: true
  formatter: "prettier --write"
  extensions:
    - .json
    - .yaml
    - .md
    - .ts
```

### Settings

| Key          | Default   | Description                                              |
| ------------ | --------- | -------------------------------------------------------- |
| `enabled`    | `true`    | Whether the plugin is active                             |
| `formatter`  | `""`      | Formatter command (receives file path as argument)       |
| `extensions` | _(empty)_ | File extensions to format (omit to let formatter decide) |

## Auto-Config

Use the `auto-config` skill to detect project formatting tools and generate settings automatically:

```
/auto-config
```

This explores the project for `.prettierrc`, `biome.json`, `pyproject.toml`, etc. and writes the appropriate config.

## Design: Auto-Config Pattern

Rather than hardcoding tool assumptions (e.g., always running prettier), this plugin uses a **config-driven** approach:

1. **No config = no action** — the hook is a no-op until configured
2. **Auto-config skill** — discovers project tools and populates config
3. **Session-start hook** (future) — can invoke auto-config via haiku on first session to auto-populate

This makes the plugin portable across projects with different toolchains.
