# github-app

Automatic GitHub App token lifecycle for Claude Code sessions.

GitHub App installation tokens expire after 1 hour. This plugin generates tokens on session start and monitors their validity via a PreToolUse hook, refreshing transparently before commands that need authentication.

## Features

- **SessionStart hook**: Generates initial installation token, configures git identity, exports credentials via runtime env file
- **PreToolUse hook**: Debounced/throttled token validity checks with smart sync/async refresh
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

The plugin supports multiple ways to provide secrets, in order of priority:

#### Option A: Bulk Secret Reference (`ref`)

The `ref` setting loads all secrets at once from a single source.

**1Password item** (recommended) — uses `nsheaps/op-exec`:

```yaml
# In $CLAUDE_PROJECT_DIR/.claude/plugins.settings.yaml
github-app:
  ref: "op://vault/github-app--repo--my-repo"
```

**Env file** — sources `KEY=VALUE` pairs from a file:

```yaml
github-app:
  ref: "env-file://./.env.github-app" # relative to project
  # or
  ref: "env-file://~/.config/agent/github-app.env" # absolute
```

The source should provide fields named:

- `GITHUB_APP_ID`
- `GITHUB_APP_CLIENT_ID`
- `GITHUB_APP_CLIENT_SECRET`
- `GITHUB_APP_PRIVATE_KEY`
- `GITHUB_INSTALLATION_ID` (optional, can be set per-project)

#### Option B: Individual Secret References

Each secret can independently reference an env var, a 1Password field, or a literal:

```yaml
github-app:
  secrets:
    github_app_id: "op://vault/item/GITHUB_APP_ID"
    github_app_client_id: "${GITHUB_APP_CLIENT_ID}"
    github_app_client_secret: "op://vault/item/GITHUB_APP_CLIENT_SECRET"
    github_app_private_key: "op://vault/item/GITHUB_APP_PRIVATE_KEY"
    github_installation_id: "12345"
```

Individual `secrets.*` values override `ref` values for the same field.

#### Option C: Environment Variables

Set before the session starts:

```bash
export GITHUB_APP_ID="12345"
export GITHUB_APP_PRIVATE_KEY_PATH="~/.config/agent/github-app.pem"
export GITHUB_INSTALLATION_ID="67890"
```

#### Option D: Legacy Flat Settings

```yaml
github-app:
  github_app_id: "12345"
  private_key_path: "~/.config/agent/github-app.pem"
  github_installation_id: "67890"
```

### Private Key Handling

The private key can be provided as:

- **File path** (`private_key_path` or `GITHUB_APP_PRIVATE_KEY_PATH`): Points to a PEM file on disk
- **Key content** (`secrets.github_app_private_key` or `GITHUB_APP_PRIVATE_KEY`): The PEM content directly (e.g., from 1Password). The plugin writes it to a secure temp file automatically.

When using a PEM file directly, ensure correct permissions:

```bash
chmod 600 ~/.config/agent/github-app.pem
```

## How It Works

1. **Session starts**: Hook reads App credentials, generates JWT, exchanges for installation token
2. **Token stored**: Written to `~/.config/agent/github-token` with 600 permissions
3. **Git identity configured**: Sets `git config user.name` and `user.email` to the App's bot identity (e.g., `my-app[bot]` / `12345+my-app[bot]@users.noreply.github.com`)
4. **Runtime env file**: `GH_TOKEN` and `GITHUB_TOKEN` written to `~/.config/agent/github-app-env`, sourced by `CLAUDE_ENV_FILE`
5. **PreToolUse monitoring**: Before each tool call, checks token expiry (debounced to every 30s)
6. **Smart refresh**: Commands using `gh`/`git push` get synchronous checks; others get async background refresh
7. **Retry with backoff**: Failed refreshes retry up to 3 times, then back off for 5 minutes
8. **Git integration**: Credential helper reads from token file for `git push`

Git identity is only configured if `user.name`/`user.email` are not already set. Disable with `auto_git_config: false` in plugin settings.

### Token Refresh Behavior

| Scenario                                          | Behavior                                  |
| ------------------------------------------------- | ----------------------------------------- |
| Token valid, >30 min remaining                    | Silent, no action                         |
| Token valid, <30 min remaining, non-token command | Background refresh, prints status         |
| Token valid, <30 min remaining, gh/git command    | Allow + background refresh, prints status |
| Token expired, gh/git command                     | Synchronous refresh before allowing       |
| Token expired, non-token command                  | Background refresh                        |
| Refresh fails                                     | Retry up to 3x with exponential backoff   |
| All retries fail                                  | 5-minute cooldown, then retry             |

## Configuration

```yaml
github-app:
  enabled: true

  # Option A: Bulk secret reference (op:// or env-file://)
  ref: "op://vault/github-app--repo--my-repo"
  # ref: "env-file://./.env.github-app"

  # Option B: Individual secrets (override ref for specific fields)
  # Each value: literal, ${ENV_VAR}, or op://vault/item/field
  secrets:
    github_app_id: "op://vault/item/GITHUB_APP_ID"
    github_app_client_id: "op://vault/item/GITHUB_APP_CLIENT_ID"
    github_app_client_secret: "op://vault/item/GITHUB_APP_CLIENT_SECRET"
    github_app_private_key: "op://vault/item/GITHUB_APP_PRIVATE_KEY"
    github_installation_id: "${GITHUB_INSTALLATION_ID}"

  # Other settings
  token_file: "~/.config/agent/github-token"
  auto_git_config: true
```

### Secret Reference Syntax

| Syntax          | Example                          | Resolution                       |
| --------------- | -------------------------------- | -------------------------------- |
| Literal         | `"12345"`                        | Used as-is                       |
| Env var         | `"${GITHUB_APP_ID}"`             | Expanded from shell environment  |
| 1Password field | `"op://vault/item/field"`        | Resolved via `op read`           |
| 1Password item  | `"op://vault/item"` (ref only)   | All fields via `op-exec`         |
| Env file        | `"env-file://./path"` (ref only) | Source KEY=VALUE pairs from file |

## Plugin Structure

```
plugins/github-app/
├── .claude-plugin/plugin.json
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       ├── github-token-init.sh     # SessionStart: initial token + env setup
│       └── github-token-check.sh    # PreToolUse: debounced validity check
├── skills/
│   ├── github-auth/SKILL.md         # Shared auth skill (symlink)
│   └── github-app-token/SKILL.md    # Token management skill
├── bin/
│   ├── generate-token.sh            # JWT generation + token exchange
│   ├── token-check.sh               # Token validity check + refresh logic
│   ├── token-status.sh              # Token status JSON output
│   └── git-credential-github-app.sh # Git credential helper
├── lib/                             # Shared libraries (symlinks)
├── docs/
│   ├── token-refresh-spec.md        # Original design spec
│   └── reference/                   # Archived implementations
└── README.md
```

## Related

- **[github](../github)** plugin — GitHub CLI installation, usage skill, and general auth
- [Design spec](docs/token-refresh-spec.md) — Original technical design document

## Security

- PEM private keys must have 600 or 400 permissions (plugin warns if not)
- Token file and runtime env file are written with 600 permissions
- Installation tokens are scoped to the App's configured permissions
- Tokens expire after 1 hour (non-extensible) and are refreshed automatically
- File-based locking prevents concurrent refresh races
