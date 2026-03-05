# GitHub App Token Lifecycle Plugin

**Status**: Implemented (v0.1.0)
**Created**: 2026-02-18
**Updated**: 2026-03-05

---

## Problem & Requirements

### Problem

GitHub App installation tokens expire after **1 hour**. In agent sessions that run for hours, tokens go stale and API calls (creating PRs, pushing commits, opening issues) fail with auth errors. The agent has no way to refresh the token mid-session.

Additionally, there's no standard way to ensure a Claude Code session starts with a valid GitHub App token. Users must manually generate tokens before launching.

### Requirements

1. **Automatic token generation**: On session start, generate a valid installation token from GitHub App credentials.
2. **Proactive refresh**: Before any tool call that uses git/gh, verify the token is still valid and refresh if needed.
3. **Transparent to agents**: `gh` CLI and `git push` should just work without agent awareness of token lifecycle.
4. **Flexible secret sourcing**: Support 1Password (`op://`), env files (`env-file://`), environment variables, and literal values.
5. **Fail-safe**: If token refresh fails, warn but don't block the session.
6. **No external dependencies beyond GitHub API**: No Redis, no database, no external token service.

### Non-Requirements

- **Token vault/secrets management**: This plugin manages ephemeral runtime tokens, not long-lived secrets.
- **Multi-provider support**: GitHub only for v1.
- **OAuth flows**: No interactive browser-based auth. Uses pre-configured GitHub App credentials.
- **MCP server**: Considered but rejected — a PreToolUse hook provides the same refresh guarantees with less complexity.

---

## Technical Design

### Architecture

The plugin uses two hooks and a set of CLI scripts:

```
┌───────────────────────────────────────────────────────┐
│ Claude Code Session                                    │
│                                                        │
│  ┌────────────────────────────────────────────────┐   │
│  │ Component 1: SessionStart Hook                  │   │
│  │ (hooks/scripts/github-token-init.sh)            │   │
│  │                                                 │   │
│  │ 1. Resolve secrets (op://, env-file://, env)    │   │
│  │ 2. Generate JWT from PEM key                    │   │
│  │ 3. Exchange JWT for installation token          │   │
│  │ 4. Write token to shared file                   │   │
│  │ 5. Write runtime env file → CLAUDE_ENV_FILE     │   │
│  │ 6. Configure git identity from App bot account  │   │
│  └────────────────────────────────────────────────┘   │
│                                                        │
│  ┌────────────────────────────────────────────────┐   │
│  │ Component 2: PreToolUse Hook                    │   │
│  │ (hooks/scripts/github-token-check.sh)           │   │
│  │                                                 │   │
│  │ Before each tool call:                          │   │
│  │ - Bash (gh/git): synchronous check              │   │
│  │   - Expired → sync refresh, then allow          │   │
│  │   - ≤30 min left → allow + background refresh   │   │
│  │   - Valid → silent allow                        │   │
│  │ - Other tools: debounced async check            │   │
│  │ Debounced to avoid excessive checks (30s)       │   │
│  └────────────────────────────────────────────────┘   │
│                                                        │
│  ┌────────────────────────────────────────────────┐   │
│  │ Shared Files                                    │   │
│  │                                                 │   │
│  │ ~/.config/agent/github-token      (token)       │   │
│  │ ~/.config/agent/github-token.meta (expiry/meta) │   │
│  │ ~/.config/agent/github-app-env    (runtime env) │   │
│  │                                                 │   │
│  │ Read by: gh CLI ($GH_TOKEN), git credential     │   │
│  │ helper, CLAUDE_ENV_FILE (re-sourced each cmd)   │   │
│  └────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────┘
```

### Why PreToolUse Instead of MCP Server

The original spec proposed a background MCP server for continuous refresh. The implementation uses a PreToolUse hook instead because:

1. **Simpler lifecycle**: No long-running process to manage, crash, or restart.
2. **Demand-driven**: Only refreshes when a tool call actually needs a token, avoiding unnecessary API calls.
3. **Same guarantee**: Every git/gh command is preceded by a freshness check, so stale tokens never reach GitHub.
4. **Debounced**: Non-token-using tools get async checks at most every 30 seconds, preventing overhead.

### Component 1: SessionStart Hook

**Trigger**: `SessionStart` event (all matchers).

**Secret Resolution** (in priority order):

1. **`ref`** — Bulk secret loading:
   - `op://vault/item` — Fetches all fields via `op-exec`, labels become env vars
   - `env-file://path` — Sources `KEY=VALUE` pairs from a file (relative paths resolve against `CLAUDE_PROJECT_DIR`)

2. **`secrets.*`** — Individual overrides (take priority over ref):
   - `${VAR_NAME}` — Expand from environment
   - `op://vault/item/field` — Resolve via `op read`
   - Literal value — Use as-is

3. **Environment variables** — `GITHUB_APP_ID`, `GITHUB_APP_PRIVATE_KEY_PATH`, `GITHUB_INSTALLATION_ID`

4. **Legacy flat settings** — `github_app_id`, `private_key_path`, `github_installation_id` in plugin config

**Private key handling**: If `GITHUB_APP_PRIVATE_KEY` contains key content (e.g., from 1Password) but no `GITHUB_APP_PRIVATE_KEY_PATH` is set, the key content is written to a secure temp file (`~/.config/agent/github-app-<app_id>.pem`, chmod 600).

**Token generation** (`bin/generate-token.sh`):

1. Generate JWT (RS256, 10-minute validity) from the PEM key
2. Exchange JWT for installation token via `POST /app/installations/{id}/access_tokens`
3. Write token to file (chmod 600)
4. Write metadata to `.meta` file (expiry, app_id, installation_id, permissions)

**Runtime env file**: Written to `~/.config/agent/github-app-env` and registered via `CLAUDE_ENV_FILE` as a `source` command. This file is re-sourced before each Bash command, so token refreshes by the PreToolUse hook are picked up automatically.

**Git identity**: If `auto_git_config: true` (default) and git user.name/email aren't already set, the hook fetches the App's slug from the API and configures git identity as `app-slug[bot] <id+app-slug[bot]@users.noreply.github.com>`.

### Component 2: PreToolUse Hook

**Trigger**: `PreToolUse` event (all matchers).

**Guards**: Skips entirely if GitHub App credentials aren't in the environment or no token file exists.

**For Bash commands using gh/git** (synchronous path):

- Checks `get_minutes_remaining()` from shared `lib/token-utils.sh`
- **expired/missing**: Synchronous refresh via `bin/token-check.sh --sync --quiet`, then allow
- **≤30 minutes**: Allow immediately, background refresh via `bin/token-check.sh --quiet &`
- **>30 minutes**: Silent allow

**For other tools** (async path):

- Debounced to 30-second intervals
- Background refresh if needed, never blocks

### Token Check Script (`bin/token-check.sh`)

Standalone script invoked by both the PreToolUse hook (sync or background) and potentially by users directly.

**Features**:

- Retry with exponential backoff (3 attempts, 2s/4s/8s)
- Cooldown period (5 minutes) after hard failure to avoid hammering the API
- File-based locking to prevent concurrent refresh races
- Updates the runtime env file on successful refresh

**Exit codes**: 0 (valid), 1 (refresh failed), 2 (not configured), 3 (in cooldown)

### Token Distribution

**Primary mechanism**: Shared file at `~/.config/agent/github-token`

Consumers:

- **`gh` CLI**: Via `$GH_TOKEN` environment variable (set by runtime env file)
- **`git push/pull`**: Via git credential helper (`bin/git-credential-github-app.sh`)
- **Direct reads**: Scripts can `cat $GITHUB_TOKEN_FILE`

The runtime env file (`~/.config/agent/github-app-env`) is sourced via `CLAUDE_ENV_FILE` before each Bash command, ensuring `$GH_TOKEN` and `$GITHUB_TOKEN` always reflect the latest token.

**Git credential helper** (`bin/git-credential-github-app.sh`):

- Responds to `get` requests by reading the token file
- No-ops on `store`/`erase` (lifecycle managed by hooks)
- Configure via: `git config --global credential.https://github.com.helper '!/path/to/git-credential-github-app.sh'`

### Plugin Structure

```
plugins/github-app/
├── .claude-plugin/
│   └── plugin.json                    # Plugin manifest
├── hooks/
│   ├── hooks.json                     # Hook registration (SessionStart + PreToolUse)
│   └── scripts/
│       ├── github-token-init.sh       # SessionStart: secret resolution + token generation
│       └── github-token-check.sh      # PreToolUse: token freshness check + refresh
├── bin/
│   ├── generate-token.sh             # JWT generation + token exchange
│   ├── token-check.sh                # Token validation + refresh with retries/locking
│   ├── token-status.sh               # JSON status report (used by diagnostics)
│   └── git-credential-github-app.sh  # Git credential helper
├── lib/
│   └── token-utils.sh                # Shared: get_minutes_remaining()
├── skills/
│   └── github-app-token/
│       └── SKILL.md                   # Agent skill documentation
├── docs/
│   └── token-refresh-spec.md          # This file
├── github-app.settings.yaml           # Default plugin configuration
└── README.md
```

### Configuration

Plugin config via `plugins.settings.yaml` (project, user, or plugin-level):

```yaml
github-app:
  enabled: true

  # Option 1: Bulk secret reference
  # ref: "op://vault/github-app--repo--my-repo"
  # ref: "env-file://./.env.github-app"

  # Option 2: Individual secrets
  # secrets:
  #   github_app_id: "op://vault/item/GITHUB_APP_ID"
  #   github_app_client_id: "${GITHUB_APP_CLIENT_ID}"
  #   github_app_private_key: "op://vault/item/GITHUB_APP_PRIVATE_KEY"
  #   github_installation_id: "67890"

  # Option 3: Legacy flat settings
  # github_app_id: "12345"
  # private_key_path: "~/.config/agent/github-app.pem"
  # github_installation_id: "67890"

  # Auto-configure git identity from App bot account (default: true)
  auto_git_config: true

  # Token file location (default: ~/.config/agent/github-token)
  # token_file: "~/.config/agent/github-token"
```

Or via environment variables: `GITHUB_APP_ID`, `GITHUB_APP_PRIVATE_KEY_PATH`, `GITHUB_INSTALLATION_ID`, `GITHUB_TOKEN_FILE`.

### Open Questions (Resolved)

1. **Can a SessionStart hook set environment variables?** — Yes, via `CLAUDE_ENV_FILE`. The hook writes a `source` command that re-reads the runtime env file on each Bash invocation.

2. **Race conditions**: File-based locking in `token-check.sh` prevents concurrent refresh attempts. The lock includes PID-based stale detection.

3. **PEM key security**: The hook validates file permissions (must be 600 or 400) and warns if too permissive.

4. **Fallback behavior**: If GitHub App auth fails, the plugin warns on stderr and allows the command to proceed. The command will fail with a 401, which is more informative than silently blocking.

### References

- [GitHub App Installation Tokens](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [GitHub App JWT Authentication](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-json-web-token-jwt-for-a-github-app)
- [Git Credential Helpers](https://git-scm.com/docs/gitcredentials)
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks)
