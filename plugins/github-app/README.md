# github-app

Automatic GitHub App token refresh for long-running Claude Code sessions.

GitHub App installation tokens expire after 1 hour. This plugin generates tokens on session start and refreshes them continuously via a background MCP server, ensuring `gh` CLI and `git push` always have valid credentials.

## Features

- **SessionStart hook**: Generates initial installation token from GitHub App credentials
- **MCP server**: Background refresh loop every 50 minutes with token management tools
- **Git credential helper**: Seamless `git push` / `gh` auth via shared token file
- **Agent team support**: Token file shared across all agents in a team session
- **Authentication skill**: Shared with `github` plugin — covers all auth methods (device code, PATs, fine-grained tokens, GitHub App auth)

## Setup

### 1. Create a GitHub App

1. Go to `https://github.com/settings/apps/new`
2. Set a name and homepage URL
3. Configure permissions (Contents: Read & Write, Pull Requests: Read & Write, etc.)
4. Generate a private key and download the PEM file

### 2. Install the App

1. Install the App on the target account or organization
2. Note the installation ID from the URL: `https://github.com/settings/installations/<ID>`

### 3. Configure Credentials

Set environment variables:

```bash
export GITHUB_APP_ID="12345"
export GITHUB_APP_PRIVATE_KEY_PATH="~/.config/agent/github-app.pem"
export GITHUB_INSTALLATION_ID="67890"
```

Or use plugin settings:

```yaml
# In $CLAUDE_PROJECT_DIR/.claude/plugins.settings.yaml
github-app:
  github_app_id: "12345"
  private_key_path: "~/.config/agent/github-app.pem"
  github_installation_id: "67890"
```

### 4. Secure the PEM key

```bash
chmod 600 ~/.config/agent/github-app.pem
```

## How It Works

1. **Session starts**: Hook reads App credentials, generates JWT, exchanges for installation token
2. **Token stored**: Written to `~/.config/agent/github-token` with 600 permissions
3. **Environment set**: `GH_TOKEN` and `GITHUB_TOKEN` exported via `CLAUDE_ENV_FILE`
4. **Background refresh**: MCP server regenerates token every 50 minutes
5. **Git integration**: Credential helper reads from token file for `git push`

## MCP Tools

| Tool                   | Description                                         |
| ---------------------- | --------------------------------------------------- |
| `token-status`         | Check token validity, expiry, and minutes remaining |
| `refresh-github-token` | Force immediate token refresh                       |
| `get-github-token`     | Get the current token value                         |

## Configuration

```yaml
github-app:
  enabled: true
  github_app_id: "12345"
  private_key_path: "~/.config/agent/github-app.pem"
  github_installation_id: "67890"
  token_file: "~/.config/agent/github-token"
  refresh_interval: 3000 # seconds (50 minutes)
```

## Plugin Structure

```
plugins/github-app/
├── .claude-plugin/plugin.json
├── hooks/
│   └── scripts/github-token-init.sh    # SessionStart: initial token
├── mcp/
│   └── token-refresh-server.sh         # Background refresh + MCP tools
├── skills/
│   ├── github-auth/SKILL.md            # Shared auth skill (symlink)
│   └── github-app-token/SKILL.md       # Token management skill
├── bin/
│   ├── generate-token.sh               # JWT generation + token exchange
│   ├── git-credential-github-app.sh    # Git credential helper
��   └── token-status.sh                 # Token status checker
├── lib/                                # Shared libraries (symlinks)
├── docs/
│   └── token-refresh-spec.md           # Original design spec
└── README.md
```

## Related

- **[github](../github)** plugin — GitHub CLI installation, usage skill, and general auth
- [Design spec](docs/token-refresh-spec.md) — Original technical design document

## Security

- PEM private keys must have 600 or 400 permissions (plugin warns if not)
- Token file is written with 600 permissions
- Installation tokens are scoped to the App's configured permissions
- Tokens expire after 1 hour (non-extensible) and are refreshed automatically
