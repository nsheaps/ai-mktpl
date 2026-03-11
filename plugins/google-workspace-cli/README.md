# google-workspace-cli

Install and manage the [Google Workspace CLI](https://github.com/googleworkspace/cli) (`gws`) in Claude Code sessions, with per-service skills for Gmail, Calendar, Drive, Docs, Sheets, Slides, Chat, Tasks, Contacts, and Admin.

## Features

- **Auto-install on web sessions**: Installs `gws` to `$project/bin/.local/` via mise or binary download
- **Per-service skills**: Individual skills for each Google Workspace service with command references
- **Overview skill**: General `gws` usage, authentication, and troubleshooting
- **Background install**: Optional non-blocking installation

## How It Works

On session start (web sessions only):

1. Checks if `gws` is already available on PATH
2. If not, tries `mise use -g ubi:googleworkspace/cli` (preferred)
3. Falls back to downloading a pre-compiled binary from GitHub releases
4. Adds `bin/.local/` to PATH via `CLAUDE_ENV_FILE`

The `bin/.local/` directory is gitignored, so installed binaries don't pollute the repo.

## Skills Included

| Skill                  | Description                                       |
| ---------------------- | ------------------------------------------------- |
| `google-workspace-cli` | Overview, installation, auth, and general usage   |
| `gmail`                | Read, send, search, draft, and manage emails      |
| `calendar`             | View events, create meetings, find free time      |
| `drive`                | List, upload, download, share files and folders   |
| `docs`                 | Create, read, and edit Google Docs                |
| `sheets`               | Read/write spreadsheet data, manage sheets        |
| `slides`               | Create and modify presentations                   |
| `chat`                 | Send messages, manage spaces                      |
| `tasks`                | Create and manage task lists and tasks            |
| `contacts`             | Search, create, and manage contacts               |
| `admin`                | User, group, and org unit management (admin only) |

## Configuration

Create or update `plugins.settings.yaml` at project or user level:

```yaml
# In $CLAUDE_PROJECT_DIR/.claude/plugins.settings.yaml
# or ~/.claude/plugins.settings.yaml

google-workspace-cli:
  enabled: true # Enable/disable the plugin
  autoInstall: true # Auto-install gws on web sessions
  installToProject: true # Install to $project/bin/.local (vs ~/.local/bin)
  backgroundInstall: false # Run install in background
  version: "latest" # Pin a specific version or use "latest"
  autoAuth: false # Auto-check auth status on startup
```

## Authentication Setup

Before using `gws`, you need to configure authentication:

1. **Create a Google Cloud project** with OAuth credentials
2. **Enable the APIs** you want to use (Gmail, Calendar, Drive, etc.)
3. **Configure OAuth consent screen**
4. **Run setup and login:**

```bash
gws auth setup    # Configure your Google Cloud project
gws auth login    # OAuth login flow
gws auth status   # Verify authentication
```

## Local Sessions

On local sessions (`CLAUDE_CODE_REMOTE` is not `true`), the install hook does nothing.
Install `gws` locally via `mise use -g ubi:googleworkspace/cli` or download the binary from the [GitHub releases](https://github.com/googleworkspace/cli/releases).

## Prerequisites

- Google Cloud project with OAuth credentials
- Google account with Workspace access (some services require paid Workspace)
