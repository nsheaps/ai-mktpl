# 1pass

Install and manage [1Password CLI](https://developer.1password.com/docs/cli/) (op) and [op-exec](https://github.com/nsheaps/op-exec) in Claude Code sessions.

## Features

- **Auto-install on web sessions**: Installs op to `$project/bin/.local/` on `CLAUDE_CODE_REMOTE=true` sessions
- **op-exec support**: Optionally installs op-exec alongside op
- **Auto-update**: Checks for and installs updates when version is "latest"
- **Background install**: Optional non-blocking installation
- **Comprehensive skills**: Full op CLI and op-exec reference for Claude

## How It Works

On session start (web sessions only):

1. Checks if op is already available on PATH
2. If `autoInstall` is true, downloads the release from 1Password
3. Extracts the binary to `$CLAUDE_PROJECT_DIR/bin/.local/op`
4. Optionally installs op-exec from GitHub releases
5. Adds `bin/.local/` to PATH via `CLAUDE_ENV_FILE`

The `bin/.local/` directory is gitignored, so installed binaries don't pollute the repo.

## Configuration

Create or update `plugins.settings.yaml` at project or user level:

```yaml
# In $CLAUDE_PROJECT_DIR/.claude/plugins.settings.yaml
# or ~/.claude/plugins.settings.yaml

1pass:
  enabled: true # Enable/disable the plugin
  autoInstall: false # Download op if not on PATH (default: false)
  installToProject: true # Install to $project/bin/.local (vs ~/.local/bin)
  backgroundInstall: false # Run install in background
  opVersion: "latest" # Pin a specific op version or use "latest"
  installOpExec: false # Also install op-exec (default: false)
  opExecVersion: "latest" # Pin a specific op-exec version or use "latest"
```

## Secrets Injection

The plugin can inject 1Password secrets as environment variables at session start. This works on **all session types** (local and web), as long as `op` is available and authenticated.

### Secrets Configuration

Each secret entry has three fields:

| Field       | Required | Description                                                  |
| ----------- | -------- | ------------------------------------------------------------ |
| `envVar`    | yes      | Environment variable name to set (e.g. `BRAINTRUST_API_KEY`) |
| `reference` | yes      | 1Password secret reference in `op://vault/item/field` format |
| `target`    | no       | Where to write the variable (default: `envFile`)             |

### Target Options

The `target` field controls where the resolved secret value is persisted:

| Target              | File written                                | Scope                                       | Committed to git?                 |
| ------------------- | ------------------------------------------- | ------------------------------------------- | --------------------------------- |
| `envFile` (default) | `$CLAUDE_ENV_FILE`                          | Current session only — gone on next session | No                                |
| `settingsJson`      | `.claude/settings.json` → `env` block       | Persists across sessions                    | **Yes** — visible in repo history |
| `settingsLocalJson` | `.claude/settings.local.json` → `env` block | Persists across sessions                    | No — gitignored                   |
| `userSettingsJson`  | `~/.claude/settings.json` → `env` block     | User-global, persists across all projects   | No — outside repo                 |

**When to use which target:**

- **`envFile`** — Best for most secrets. Session-scoped, no disk persistence, no git risk. Re-injected fresh each session from 1Password. This is the default and recommended target.
- **`settingsLocalJson`** — Use when you need the secret to survive across sessions without re-injection (e.g. if `op` auth is only available during initial setup). The file is gitignored so secrets won't leak to the repo.
- **`userSettingsJson`** — Use for secrets that should be available across all projects for a user. Writes to `~/.claude/settings.json` which is outside any repo. Good for API keys used across multiple projects (e.g. `BRAINTRUST_API_KEY`).
- **`settingsJson`** — Use only for non-sensitive values you want committed. **Never use this for actual secrets** — the file is tracked by git.

### Example

```yaml
1pass:
  enabled: true
  secrets:
    # API key re-injected each session (recommended)
    - envVar: BRAINTRUST_API_KEY
      reference: "op://Personal/Braintrust/api-key"
      target: envFile

    # Persists locally between sessions (gitignored)
    - envVar: DATABASE_URL
      reference: "op://Work/Production DB/connection_string"
      target: settingsLocalJson

    # Non-secret config value committed to repo
    - envVar: SENTRY_ORG
      reference: "op://Work/Sentry/org-slug"
      target: settingsJson

    # target defaults to envFile when omitted
    - envVar: ANTHROPIC_API_KEY
      reference: "op://Work/Claude API Key/credential"
```

## Authentication

The op CLI requires authentication. Options:

- **Service account**: Set `OP_SERVICE_ACCOUNT_TOKEN` environment variable
- **Interactive**: Run `op signin` (local sessions only)
- **Connect server**: Set `OP_CONNECT_HOST` and `OP_CONNECT_TOKEN`

## Using with mise (recommended for this repo)

Instead of auto-install, this repo manages op and op-exec via mise:

```toml
# mise.toml
[tools]
"vfox:mise-plugins/vfox-1password" = "latest"
"github:nsheaps/op-exec" = "latest"
```

## Local Sessions

On local sessions (`CLAUDE_CODE_REMOTE` is not `true`), this plugin does nothing.
It assumes op is already installed locally via Homebrew, mise, or another method.

## Pattern: Project-Local Tool Installation

This plugin follows the **project-local binary** pattern for web sessions:

1. Tools install to `$CLAUDE_PROJECT_DIR/bin/.local/`
2. `bin/.local/` is listed in `.gitignore`
3. The session start hook adds `bin/.local/` to `PATH` via `CLAUDE_ENV_FILE`
4. Each web session gets fresh installs (no persistent state assumed)

This pattern ensures:

- No system-level modifications needed
- No conflicts between projects using different versions
- Clean git state (binaries are gitignored)
- Works in restricted web environments
