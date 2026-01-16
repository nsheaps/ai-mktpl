# Claude Diagnostics Plugin

A diagnostic tool that captures Claude Code status, context, and configuration files for troubleshooting.

## Installation

This plugin is part of the nsheaps/.ai marketplace. The binary is automatically symlinked to your PATH via the SessionStart hook.

## Usage

```bash
claude-diagnostics [OPTIONS]
```

## Options

| Option          | Description                                            |
| --------------- | ------------------------------------------------------ |
| `-v, --verbose` | Print diagnostics to console (quiet by default)        |
| `--no-archive`  | Only print diagnostics to stdout, don't create archive |
| `--no-user`     | Exclude user-level config (~/.claude/, ~/.ai/)         |
| `--no-project`  | Exclude project-level config (.claude/, .ai/)          |
| `--no-rules`    | Exclude rules files                                    |
| `--no-agents`   | Exclude agent definitions                              |
| `--no-commands` | Exclude command/skill files                            |
| `--no-settings` | Exclude settings.json files                            |
| `-h, --help`    | Show help message                                      |

## Output

The tool creates a `.tar.gz` archive in `/tmp/` containing:

- `diagnostics.md` - Human-readable status report including:
  - Claude Code version and model
  - Permission mode and API key source
  - MCP servers and their status
  - Loaded plugins
  - Available slash commands and agents
  - Context output (equivalent to `/context` command)
- `init.json` - Raw JSON from Claude Code initialization
- `user-config/` - User-level configuration files (if not excluded)
- `project-config/` - Project-level configuration files (if not excluded)
- `manifest.txt` - List of all files in the archive

## Examples

```bash
# Create full diagnostic archive
claude-diagnostics

# Print diagnostics to stdout only (no archive)
claude-diagnostics --no-archive

# Create archive excluding sensitive user config
claude-diagnostics --no-user --no-settings

# Verbose output with archive
claude-diagnostics -v
```

## Security Note

Always review the archive contents before sharing, as it may contain:

- API keys or tokens in settings files
- Personal paths and usernames
- Project-specific configuration

Use the exclusion options to filter sensitive data.
