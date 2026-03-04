# gh-tool

Install and manage [GitHub CLI](https://cli.github.com/) (gh) in Claude Code sessions.

## Features

- **Auto-install on web sessions**: Installs gh to `$project/bin/.local/` on `CLAUDE_CODE_REMOTE=true` sessions
- **Auto-update**: Checks for and installs updates when version is "latest"
- **Auth verification**: Optionally runs `gh auth status` after install
- **Background install**: Optional non-blocking installation
- **Comprehensive skill**: Full gh CLI reference for Claude

## How It Works

On session start (web sessions only):

1. Checks if gh is already available on PATH
2. If not, downloads the release tarball from GitHub
3. Extracts the binary to `$CLAUDE_PROJECT_DIR/bin/.local/gh`
4. Adds `bin/.local/` to PATH via `CLAUDE_ENV_FILE`
5. Verifies authentication status

The `bin/.local/` directory is gitignored, so installed binaries don't pollute the repo.

## Configuration

Create or update `plugins.settings.yaml` at project or user level:

```yaml
# In $CLAUDE_PROJECT_DIR/.claude/plugins.settings.yaml
# or ~/.claude/plugins.settings.yaml

gh-tool:
  enabled: true # Enable/disable the plugin
  install_to_project: true # Install to $project/bin/.local (vs ~/.local/bin)
  background_install: false # Run install in background
  version: "latest" # Pin a specific version or use "latest"
  auto_auth_check: true # Run `gh auth status` after install
```

## Authentication

The gh CLI requires authentication. In web sessions, set `GH_TOKEN` as an
environment variable. The plugin will verify auth status on session start.

## Local Sessions

On local sessions (`CLAUDE_CODE_REMOTE` is not `true`), this plugin does nothing.
It assumes gh is already installed locally via Homebrew, mise, or another method.

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
