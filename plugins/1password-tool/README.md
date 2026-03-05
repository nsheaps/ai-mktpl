# 1password-tool

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
2. If `auto_install` is true, downloads the release from 1Password
3. Extracts the binary to `$CLAUDE_PROJECT_DIR/bin/.local/op`
4. Optionally installs op-exec from GitHub releases
5. Adds `bin/.local/` to PATH via `CLAUDE_ENV_FILE`

The `bin/.local/` directory is gitignored, so installed binaries don't pollute the repo.

## Configuration

Create or update `plugins.settings.yaml` at project or user level:

```yaml
# In $CLAUDE_PROJECT_DIR/.claude/plugins.settings.yaml
# or ~/.claude/plugins.settings.yaml

1password-tool:
  enabled: true # Enable/disable the plugin
  auto_install: false # Download op if not on PATH (default: false)
  install_to_project: true # Install to $project/bin/.local (vs ~/.local/bin)
  background_install: false # Run install in background
  op_version: "latest" # Pin a specific op version or use "latest"
  install_op_exec: false # Also install op-exec (default: false)
  op_exec_version: "latest" # Pin a specific op-exec version or use "latest"
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
# op-exec once available via GitHub releases:
# "ubi:nsheaps/op-exec" = "latest"
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
