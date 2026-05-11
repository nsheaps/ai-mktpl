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

As of 0.4.0, the plugin no longer resolves secrets itself. The agent launcher
(`bin/agent`) is responsible for sourcing the agent's `.env` / `.env.local`
chain before exec'ing `claude`, so the following env vars are present at hook
time:

- `GITHUB_APP_ID`
- `GITHUB_APP_INSTALLATION_ID`
- `GITHUB_APP_PRIVATE_KEY_PATH` — absolute path to PEM file on disk

The launcher's `.env.local` is typically managed by the 1pass plugin (which
materializes 1Password items to disk). The github-app plugin is decoupled
from 1Password and works with any mechanism that lands the right env vars
in process env.

If any required var is missing when the SessionStart hook fires, the plugin
fails loudly with a one-line message naming each missing var.

### Private Key Handling

`GITHUB_APP_PRIVATE_KEY_PATH` must point to a PEM file on disk with 600 or
400 permissions:

```bash
chmod 600 ~/.agents/<agent-name>/.config/github-app.pem
```

Inline PEM content (`GITHUB_APP_PRIVATE_KEY`) is no longer supported by this
plugin — write the PEM to disk in your launcher chain (the 1pass plugin does
this automatically when a `GITHUB_APP_PRIVATE_KEY` field is present).

## How It Works

1. **Session starts**: SessionStart hook validates required env vars
   (`GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, `GITHUB_APP_PRIVATE_KEY_PATH`),
   generates a JWT, exchanges for an installation token
2. **Token stored**: Written to `${XDG_CONFIG_HOME}/github-app/token` (i.e.
   `$AGENT_HOME_DIR/.config/github-app/token`) with 600 permissions. `AGENT_NAME`
   must be set — the plugin refuses to run without it.
3. **Git identity configured**: Sets `GIT_AUTHOR_*`/`GIT_COMMITTER_*` env vars to the App's bot identity (e.g., `my-app[bot]` / `12345+my-app[bot]@users.noreply.github.com`). Only configures if `user.name`/`user.email` are not already set in git config.
4. **Runtime env file**: `GH_TOKEN` and `GITHUB_TOKEN` written to
   `${XDG_CONFIG_HOME}/github-app/runtime.env`, sourced via `CLAUDE_ENV_FILE`
5. **PreToolUse monitoring**: Before each tool call, checks token expiry (debounced to every 30s)
6. **Smart refresh**: Commands using `gh`/`git push` get synchronous checks; others get async background refresh
7. **Retry with backoff**: Failed refreshes retry up to 3 times, then back off for 5 minutes
8. **Git integration**: Credential helper reads from token file for `git push`

Git identity is only configured if `user.name`/`user.email` are not already set in git config. When they are, the existing config is exported as env vars so sub-agents inherit the right identity. Disable with `autoGitConfig: false` in plugin settings.

### Token Refresh Behavior

| Scenario                                          | Behavior                                  |
| ------------------------------------------------- | ----------------------------------------- |
| Token valid, >45 min remaining                    | Silent, no action                         |
| Token valid, <45 min remaining, non-token command | Background refresh, prints status         |
| Token valid, <45 min remaining, gh/git command    | Allow + background refresh, prints status |
| Token expired, gh/git command                     | Synchronous refresh before allowing       |
| Token expired, non-token command                  | Background refresh                        |
| Refresh fails                                     | Retry up to 3x with exponential backoff   |
| All retries fail                                  | 5-minute cooldown, then retry             |

## Configuration

```yaml
github-app:
  enabled: true

  # Automatically set GIT_AUTHOR_* / GIT_COMMITTER_* from the App's bot
  # identity (e.g. "my-app[bot]" + noreply email). Default: true.
  autoGitConfig: true

  # Override the token file path. Defaults to
  # ${XDG_CONFIG_HOME}/github-app/token.
  # tokenFile: "~/.agents/<agent-name>/.config/github-app/token"
```

Static credentials (`GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`,
`GITHUB_APP_PRIVATE_KEY_PATH`) come from process env — set by the launcher's
`.env` chain, NOT by this plugin's settings. See the "Configure Credentials"
section above.

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

## Upgrading from 0.1.x

### Migration

v0.2.0 moves credential storage from `~/.config/agent/` to `~/.agents/${AGENT_NAME}/.config/`. On first session start after upgrading, a fresh token is generated under the new path. The old files at `~/.config/agent/` become orphaned and can be safely deleted:

```bash
rm -rf ~/.config/agent/github-token ~/.config/agent/github-token.meta ~/.config/agent/github-app-env
```

### AGENT_NAME for git credential helper

`bin/git-credential-github-app.sh` is invoked by **git itself** outside the
Claude harness. The helper prefers `GITHUB_TOKEN_FILE` from the environment
(set by SessionStart via `runtime.env` / `CLAUDE_ENV_FILE`) and skips the
agent-name guard when that's available.

If you need to invoke the helper from a shell where `GITHUB_TOKEN_FILE` is
not exported, export `AGENT_NAME` and `XDG_CONFIG_HOME` so path derivation
works:

```bash
# ~/.bashrc or ~/.zshrc
export AGENT_NAME="jack"  # or "henry", etc.
export XDG_CONFIG_HOME="$HOME/.agents/$AGENT_NAME/.config"
```

If `AGENT_NAME` is unset, the helper refuses to run — there is no `_UNKNOWN`
fallback (PR #487 removed `GITHUB_APP_ALLOW_UNKNOWN_AGENT`).

## Related

- **[github](../github)** plugin — GitHub CLI installation, usage skill, and general auth
- [Design spec](docs/token-refresh-spec.md) — Original technical design document

## Security

- PEM private keys must have 600 or 400 permissions (plugin warns if not)
- Token file and runtime env file are written with 600 permissions
- Installation tokens are scoped to the App's configured permissions
- Tokens expire after 1 hour (non-extensible) and are refreshed automatically
- File-based locking prevents concurrent refresh races
