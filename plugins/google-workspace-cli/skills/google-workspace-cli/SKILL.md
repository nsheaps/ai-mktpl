---
name: google-workspace-cli
description: >
  Use this skill when the user asks about the Google Workspace CLI (gws),
  installing or configuring gws, authenticating with Google Workspace,
  or performing any task across multiple Google Workspace services.
  Also use when the user mentions "gws" or "Google Workspace CLI".
---

# Google Workspace CLI (gws)

The Google Workspace CLI (`gws`) provides a unified command-line interface for
interacting with Google Workspace APIs including Gmail, Calendar, Drive, Docs,
Sheets, Slides, Chat, Tasks, Contacts, and Admin.

Commands are dynamically built from Google's Discovery Service, so new API
endpoints become available automatically without software updates.

## Installation

```bash
# Via mise (recommended)
mise use -g ubi:googleworkspace/cli

# Via pre-compiled binary (Linux x64)
curl -fsSL https://github.com/googleworkspace/cli/releases/latest/download/gws-linux-x64 -o gws
chmod +x gws
```

## Authentication

```bash
# First-time setup: configure your Google Cloud project
gws auth setup

# Log in with OAuth
gws auth login

# Check auth status
gws auth status
```

**Requirements:**

- A Google Cloud project with OAuth credentials configured
- Gmail, Calendar, Drive, and other APIs enabled in the project
- OAuth consent screen configured

## General Usage

```bash
# List available services
gws help

# Get help for a specific service
gws <service> help

# JSON output for scripting/agent workflows
gws <service> <command> --format json
```

## Key Features

- **Unified interface** for all Google Workspace services
- **JSON output** (`--format json`) for machine parsing and agent workflows
- **Dynamic commands** from Google's Discovery Service (auto-updated)
- **OAuth and service account** authentication
- **AES-256-GCM** credential encryption

## Plugin Settings

This plugin auto-installs `gws` on web sessions. Configure via `plugins.settings.yaml`:

```yaml
google-workspace-cli:
  enabled: true
  autoInstall: true
  installToProject: true
  backgroundInstall: false
  version: "latest"
  autoAuth: false
```

Place in:

- `$CLAUDE_PROJECT_DIR/.claude/plugins.settings.yaml` (project-level)
- `~/.claude/plugins.settings.yaml` (user-level)

## Troubleshooting

### "gws: command not found"

Ensure the session start hook ran. Check `$CLAUDE_PROJECT_DIR/bin/.local/` for
the binary. On local sessions, install via `mise use -g ubi:googleworkspace/cli` or download from GitHub releases.

### Authentication errors

Run `gws auth setup` to configure your Google Cloud project, then `gws auth login`.

### API not enabled

Enable the relevant API (Gmail, Calendar, Drive, etc.) in your Google Cloud Console
project settings.
