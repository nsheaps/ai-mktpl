---
name: mise
description: >
  Use this skill when the user asks about managing tool versions, installing
  development tools, working with mise.toml, setting up project environments,
  using mise backends, managing environment variables with mise, or any task
  involving the mise tool version manager. Also use when encountering "command
  not found" errors for development tools that could be managed by mise.
---

# mise - Tool Version Manager

mise (formerly rtx) is a polyglot tool version manager. It manages runtime
versions for languages and tools (node, python, ruby, go, rust, etc.) using
a single `mise.toml` configuration file per project.

## Quick Reference

### Installation

```bash
# Install via curl (recommended for CI/web sessions)
curl https://mise.run | sh

# Install via Homebrew (macOS/Linux)
brew install mise

# Install via GitHub releases (direct binary)
MISE_VERSION="2024.12.16"
curl -fsSL "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-x64" -o mise
chmod +x mise
```

### Shell Activation

```bash
# bash
eval "$(mise activate bash)"

# zsh
eval "$(mise activate zsh)"

# fish
mise activate fish | source
```

### Core Commands

| Command                         | Description                               |
| ------------------------------- | ----------------------------------------- |
| `mise install`                  | Install all tools from mise.toml          |
| `mise install <tool>@<version>` | Install specific tool version             |
| `mise use <tool>@<version>`     | Add tool to mise.toml and install         |
| `mise ls`                       | List installed tool versions              |
| `mise ls-remote <tool>`         | List available remote versions            |
| `mise trust`                    | Trust the current directory's config      |
| `mise self-update`              | Update mise itself                        |
| `mise doctor`                   | Check mise health and configuration       |
| `mise env`                      | Show environment variables mise would set |
| `mise exec -- <command>`        | Run command with mise-managed tools       |

## Configuration (mise.toml)

### Basic Structure

```toml
[tools]
node = "22"           # Major version (auto-resolves to latest 22.x.x)
python = "3.12.1"     # Exact version
bun = "latest"        # Always latest stable
go = "1.22"           # Minor version pin
"npm:prettier" = "latest"  # npm package as tool

[settings]
legacy_version_file = false  # Don't read .node-version, .python-version etc.

[env]
NODE_ENV = "development"
DATABASE_URL = "postgres://localhost/mydb"
```

### Version Specifiers

```toml
[tools]
node = "22"          # Fuzzy: latest 22.x
node = "22.11.0"     # Exact version
node = "lts"         # Latest LTS
node = "latest"      # Latest stable
node = "sub-0.1"     # Sub-version prefix
```

### Multiple Versions

```toml
[tools]
python = ["3.12", "3.11"]  # Install both, 3.12 is default
```

### Tool Backends

mise supports multiple package ecosystems:

```toml
[tools]
# Core tools (built-in support)
node = "22"
python = "3.12"
go = "1.22"
ruby = "3.3"
java = "21"
rust = "1.77"

# npm packages
"npm:prettier" = "latest"
"npm:eslint" = "latest"
"npm:typescript" = "5"

# pip packages
"pipx:black" = "latest"

# cargo packages
"cargo:ripgrep" = "latest"

# go packages
"go:golang.org/x/tools/gopls" = "latest"

# GitHub releases via ubi (Universal Binary Installer)
"ubi:cli/cli" = "latest"           # GitHub CLI
"ubi:casey/just" = "latest"        # just task runner
"ubi:jqlang/jq" = "latest"        # jq JSON processor

# aqua registry
"aqua:cli/cli" = "latest"
```

### Environment Variables

```toml
[env]
# Static values
DATABASE_URL = "postgres://localhost/mydb"
NODE_ENV = "development"

# Reference other env vars
HOME_BIN = "{{env.HOME}}/bin"

# File-based env (like dotenv)
_.file = ".env"

# Path manipulation
_.path = ["./bin", "./node_modules/.bin"]
```

### Tasks

```toml
[tasks.build]
run = "npm run build"
description = "Build the project"
depends = ["install"]

[tasks.test]
run = "npm test"
description = "Run tests"

[tasks.install]
run = "npm install"
description = "Install dependencies"
```

## Common Workflows

### Setting Up a New Project

```bash
# Initialize mise for a project
mise use node@22 python@3.12 bun@latest

# This creates/updates mise.toml with the specified tools
# and installs them immediately
```

### Adding a New Tool

```bash
# Add a tool and pin version in mise.toml
mise use go@1.22

# Add npm-based tool
mise use npm:prettier@latest

# Add from GitHub releases
mise use ubi:casey/just@latest
```

### Updating Tools

```bash
# Update all tools to latest matching versions
mise upgrade

# Update specific tool
mise upgrade node

# Update mise itself
mise self-update
```

### Listing and Checking

```bash
# List all installed versions
mise ls

# List what versions are available for a tool
mise ls-remote node

# Check for outdated tools
mise outdated

# Verify mise configuration health
mise doctor
```

### CI/CD Integration

```bash
# In CI, trust and install without prompts
mise trust
mise install -y

# Run a command with mise-managed tools
mise exec -- npm test

# Or activate in the shell
eval "$(mise activate bash)"
npm test
```

### Environment Variable Management

```bash
# Show what env vars mise would set
mise env

# Set an env var in mise.toml
mise set NODE_ENV=production

# Unset an env var
mise unset NODE_ENV
```

## Plugin Settings

This plugin supports configuration via `plugins.settings.yaml`:

```yaml
mise:
  enabled: true
  install_to_project: true # Install to $project/bin/.local
  background_install: false # Install in background
  version: "latest" # Specific version or "latest"
  auto_install_tools: true # Run mise install after setup
  auto_trust: true # Auto-trust project mise.toml
```

Place in:

- `$CLAUDE_PROJECT_DIR/.claude/plugins.settings.yaml` (project-level)
- `~/.claude/plugins.settings.yaml` (user-level)

## Troubleshooting

### "command not found" after install

Ensure mise is activated in your shell. Run `eval "$(mise activate bash)"`.

### Tools not installing

1. Check `mise doctor` for configuration issues
2. Ensure `mise.toml` is trusted: `mise trust`
3. Check network connectivity for downloads

### Version conflicts with system tools

mise shims take precedence when activated. Use `mise which <tool>` to verify
which version is being used.

### Web session specifics

In Claude Code web sessions, mise is auto-installed by this plugin to
`$CLAUDE_PROJECT_DIR/bin/.local/mise`. The PATH is updated via `CLAUDE_ENV_FILE`.
If tools aren't available, check that the session start hook completed.
