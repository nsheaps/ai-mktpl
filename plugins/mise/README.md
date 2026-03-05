# mise

Install and manage [mise](https://mise.run) (tool version manager) in Claude Code sessions.

## Features

- **Auto-install on web sessions**: Installs mise to `$project/bin/.local/` on `CLAUDE_CODE_REMOTE=true` sessions
- **Auto-update**: Updates existing installations when version is set to "latest"
- **Auto-trust & install**: Automatically trusts `mise.toml` and installs project tools
- **Background install**: Optional non-blocking installation
- **Comprehensive skill**: Full mise workflow reference for Claude

## How It Works

On session start (web sessions only):

1. Checks if mise is already available on PATH
2. If not, downloads the binary to `$CLAUDE_PROJECT_DIR/bin/.local/mise`
3. Adds `bin/.local/` to PATH via `CLAUDE_ENV_FILE`
4. Activates mise in the shell
5. Trusts the project config and installs tools from `mise.toml`

The `bin/.local/` directory is gitignored, so installed binaries don't pollute the repo.

## Configuration

Create or update `plugins.settings.yaml` at project or user level:

```yaml
# In $CLAUDE_PROJECT_DIR/.claude/plugins.settings.yaml
# or ~/.claude/plugins.settings.yaml

mise:
  enabled: true # Enable/disable the plugin
  install_to_project: true # Install to $project/bin/.local (vs ~/.local/bin)
  background_install: false # Run install in background
  version: "latest" # Pin a specific version or use "latest"
  auto_install_tools: true # Run `mise install` after setup
  auto_trust: true # Run `mise trust` for project config
```

## Local Sessions

On local sessions (`CLAUDE_CODE_REMOTE` is not `true`), this plugin does nothing.
It assumes mise is already installed locally via Homebrew or another method.

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
