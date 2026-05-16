# github-app

env-var driven GitHub App token lifecycle for Claude Code sessions.

GitHub App installation tokens expire after 1 hour. This plugin generates tokens on session start and monitors their validity via a PreToolUse hook, refreshing transparently before commands that need authentication.

## Features

- **SessionStart hook**: Reads credentials from env vars, materializes PEM, generates installation token, configures git identity, exports credentials via runtime env file
- **PreToolUse hook**: Debounced/throttled token validity checks with smart sync/async refresh
- **Git credential helper**: Seamless `git push` / `gh` auth via shared token file
- **Per-agent isolation**: All files written under `$CLAUDE_PLUGIN_DATA/` — each agent automatically gets its own isolated directory
- **Authentication skill**: Shared with `github` plugin — covers all auth methods

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

Set these three env vars before the session starts:

- `GITHUB_APP_ID`
- `GITHUB_INSTALLATION_ID`
- `GITHUB_APP_PRIVATE_KEY` (PEM content — not a file path)

**Recommended**: Use the **1pass plugin** to inject from 1Password. Add to your agent's `plugins.settings.yaml`:

```yaml
1pass:
  secrets:
    - envVar: GITHUB_APP_ID
      reference: 'op://vault/github-app--repo--my-repo/GITHUB_APP_ID'
    - envVar: GITHUB_INSTALLATION_ID
      reference: 'op://vault/github-app--repo--my-repo/GITHUB_INSTALLATION_ID'
    - envVar: GITHUB_APP_PRIVATE_KEY
      reference: 'op://vault/github-app--repo--my-repo/GITHUB_APP_PRIVATE_KEY'

github-app:
  enabled: true
  autoGitConfig: true
```

Any mechanism that exports these vars into the session env works (direct export, `.env` file sourced before launch, etc.). The 1pass plugin is simply the recommended approach.

## How It Works

1. **Session starts**: Hook reads three env vars, materializes PEM to `$CLAUDE_PLUGIN_DATA/github-app.pem`
2. **Token generated**: JWT created from PEM, exchanged for installation token via GitHub API
3. **Token stored**: Written to `$CLAUDE_PLUGIN_DATA/github-token` (mode 600)
4. **Git identity configured**: Sets `GIT_AUTHOR_*`/`GIT_COMMITTER_*` to the App's bot identity (e.g., `my-app[bot]`). Controlled by `autoGitConfig: true` (default).
5. **Runtime env file**: `GH_TOKEN` and `GITHUB_TOKEN` written to `$CLAUDE_PLUGIN_DATA/github-app-env`, sourced by `CLAUDE_ENV_FILE`
6. **PreToolUse monitoring**: Before each tool call, checks token expiry (debounced to every 5 min)
7. **Smart refresh**: Commands using `gh`/`git push` get synchronous checks; others get async background refresh
8. **Retry with backoff**: Failed refreshes retry up to 3 times, then back off for 5 minutes

### Token Refresh Behavior

| Scenario | Behavior |
| --------- | -------- |
| Token valid, >45 min remaining | Silent, no action |
| Token valid, <45 min remaining, non-token command | Background refresh |
| Token valid, <45 min remaining, gh/git command | Allow + background refresh |
| Token expired, gh/git command | Synchronous refresh before allowing |
| Token expired, non-token command | Background refresh |
| Refresh fails | Retry up to 3x with exponential backoff |
| All retries fail | 5-minute cooldown, then retry |

## Configuration

```yaml
github-app:
  enabled: true
  autoGitConfig: true
  # How long SessionStart waits for env vars to appear (seconds).
  # Set to 0 to disable.
  waitForEnvTimeoutSeconds: 15
```

## On-disk Layout

All files are written under `$CLAUDE_PLUGIN_DATA/` (per-agent isolated automatically):

```
$CLAUDE_PLUGIN_DATA/
├── github-app.pem            # Materialized PEM (mode 600, rewritten each SessionStart)
├── github-token              # Raw token (mode 600)
├── github-token.meta         # JSON: expires_at, app_id, installation_id, app_slug, bot_id
├── github-token.cooldown     # After 3 failed retries (5-min backoff)
├── github-token.lock         # Mutex for concurrent refresh
├── github-app-env            # Runtime env file sourced via CLAUDE_ENV_FILE
├── github-git-identity       # Stable identity file (not overwritten by token refresh)
├── github-app-last-check     # Debounce timestamp
├── gh/                       # Isolated GH_CONFIG_DIR
└── git/config                # Isolated GIT_CONFIG_GLOBAL target
```

## Plugin Structure

```
plugins/github-app/
├── .claude-plugin/plugin.json
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       ├── github-token-init.sh     # SessionStart: credential check, PEM materialization, token + env setup
│       └── github-token-check.sh    # PreToolUse: debounced validity check
├── skills/
│   ├── github-auth/SKILL.md         # Shared auth skill (symlink)
│   └── github-app-token/SKILL.md    # Token management skill
├── bin/
│   ├── generate-token.sh            # JWT generation + token exchange
│   ├── token-check.sh               # Token validity check + refresh logic
│   └── token-status.sh              # Token status JSON output
├── lib/
│   ├── env-file.sh                  # Runtime env file writer
│   ├── token-utils.sh               # Token expiry helpers
│   └── wait-for-env.sh              # Poll CLAUDE_ENV_FILE for vars
├── docs/
│   └── reference/                   # Archived implementations
└── README.md
```

## Upgrading from 0.3.x

### Breaking changes in v0.4.0

- **Env-var contract simplified**: Only `GITHUB_APP_ID`, `GITHUB_INSTALLATION_ID`, `GITHUB_APP_PRIVATE_KEY` are read. The `GITHUB_APP_PRIVATE_KEY_PATH` input var is gone — provide PEM content directly.
- **`GITHUB_INSTALLATION_ID` renamed**: Use `GITHUB_INSTALLATION_ID`.
- **`ref:` and `secrets.*` settings removed**: The plugin no longer resolves secrets from 1Password directly. Use the 1pass plugin's `secrets:` list instead.
- **Paths moved**: All runtime files now live under `$CLAUDE_PLUGIN_DATA/` instead of `~/.agents/<name>/.config/`.

### Migration

Update your agent's `plugins.settings.yaml`:

```yaml
# Before (v0.3.x):
github-app:
  ref: 'op://vault/github-app--repo--my-repo'

# After (v0.4.0):
github-app:
  enabled: true
  autoGitConfig: true

1pass:
  secrets:
    - envVar: GITHUB_APP_ID
      reference: 'op://vault/github-app--repo--my-repo/GITHUB_APP_ID'
    - envVar: GITHUB_INSTALLATION_ID
      reference: 'op://vault/github-app--repo--my-repo/GITHUB_INSTALLATION_ID'
    - envVar: GITHUB_APP_PRIVATE_KEY
      reference: 'op://vault/github-app--repo--my-repo/GITHUB_APP_PRIVATE_KEY'
```

After the first session start on v0.4.0, old files at `~/.agents/<name>/.config/` become orphaned and can be cleaned up:

```bash
rm -rf ~/.agents/<name>/.config/github-token* ~/.agents/<name>/.config/github-app-env \
       ~/.agents/<name>/.config/github-app.pem ~/.agents/<name>/.config/github-git-identity
```

### Git credential helper

The credential helper configuration is unchanged from v0.3.x:

```ini
[credential "https://github.com"]
    helper =
    helper = !gh auth git-credential
```

## Related

- **[github](../github)** plugin — GitHub CLI installation, usage skill, and general auth

## Security

- PEM is materialized from `$GITHUB_APP_PRIVATE_KEY` on every session start — never cached across sessions
- Token file and runtime env file are written with mode 600
- Installation tokens are scoped to the App's configured permissions
- Tokens expire after 1 hour (non-extensible) and are refreshed automatically
- File-based locking prevents concurrent refresh races
