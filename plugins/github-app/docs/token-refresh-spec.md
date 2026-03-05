# GitHub Token Refresh Plugin

**Status**: Draft
**Created**: 2026-02-18
**Author**: Road Runner (Researcher)

<!-- TODO: Link to agent-github-auth spec once migrated from claude-utils -->

---

## Problem & Requirements

### Problem

GitHub App installation tokens expire after **1 hour**. In agent team sessions that run for hours, tokens go stale and API calls (creating PRs, pushing commits, opening issues) start failing silently or with auth errors. The agent has no way to refresh the token mid-session.

Today, if a user sets `GITHUB_TOKEN` at session start, it remains static for the entire session. For long-lived personal access tokens this is fine, but for GitHub App installation tokens (the recommended approach for agent identity), token refresh is essential.

Additionally, there's no standard way to ensure a Claude Code session starts with a valid GitHub App token. Users must manually generate tokens before launching.

### Requirements

1. **Automatic token refresh**: The plugin must refresh GitHub App installation tokens before they expire, ensuring `GITHUB_TOKEN` (or equivalent) always contains a valid token.
2. **SessionStart initialization**: When the session starts and GitHub App env vars are present (`GITHUB_APP_ID`, `GITHUB_APP_PRIVATE_KEY_PATH`, `GITHUB_INSTALLATION_ID`), automatically generate an initial token.
3. **Transparent to agents**: Agents should not need to know about token refresh. `gh` CLI and `git push` should just work.
4. **Configurable**: Support multiple token sources (GitHub App, fine-grained PAT rotation, etc.) via plugin config.
5. **Fail-safe**: If token refresh fails, warn the user but don't crash the session.
6. **No external dependencies**: Should work with just the GitHub API — no Redis, no database, no external token service.

### Non-Requirements

- **Token vault/secrets management**: This plugin manages ephemeral runtime tokens, not long-lived secrets. PEM keys are stored by the user.
- **Multi-provider support**: GitHub only for v1. Other providers (GitLab, Bitbucket) are future work.
- **OAuth flows**: No interactive browser-based auth. This plugin uses pre-configured GitHub App credentials.

---

## Technical Design

### Architecture

The plugin has two components working together:

```
┌─────────────────────────────────────────────────┐
│ Claude Code Session                              │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │ Component 1: SessionStart Hook            │   │
│  │                                           │   │
│  │ On session start:                         │   │
│  │ 1. Check for GITHUB_APP_ID env var        │   │
│  │ 2. Generate JWT from PEM key              │   │
│  │ 3. Exchange JWT for installation token    │   │
│  │ 4. Write token to shared file             │   │
│  │ 5. Set GITHUB_TOKEN in environment        │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │ Component 2: MCP Server (background)      │   │
│  │                                           │   │
│  │ Runs continuously:                        │   │
│  │ - Refreshes token every 50 minutes        │   │
│  │ - Writes new token to shared file         │   │
│  │ - Exposes tools:                          │   │
│  │   • get-github-token (returns current)    │   │
│  │   • refresh-github-token (force refresh)  │   │
│  │   • token-status (expiry, app info)       │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │ Token File: ~/.config/agent/github-token  │   │
│  │                                           │   │
│  │ Read by: gh CLI, git credential helper,   │   │
│  │          agents via MCP tool              │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

### Component 1: SessionStart Hook

**Trigger**: `SessionStart` event, when all of these env vars are set:

- `GITHUB_APP_ID` — The GitHub App's ID
- `GITHUB_APP_PRIVATE_KEY_PATH` — Path to PEM file (e.g., `~/.config/agent/github-app.pem`)
- `GITHUB_INSTALLATION_ID` — The installation ID for the target account/org

**Hook script** (`hooks/github-token-init.sh`):

```bash
#!/usr/bin/env bash
set -euo pipefail

# Skip if GitHub App not configured
[[ -z "${GITHUB_APP_ID:-}" ]] && exit 0
[[ -z "${GITHUB_APP_PRIVATE_KEY_PATH:-}" ]] && exit 0
[[ -z "${GITHUB_INSTALLATION_ID:-}" ]] && exit 0

TOKEN_FILE="${GITHUB_TOKEN_FILE:-$HOME/.config/agent/github-token}"
mkdir -p "$(dirname "$TOKEN_FILE")"

# Generate JWT (10-minute validity)
NOW=$(date +%s)
IAT=$((NOW - 60))
EXP=$((NOW + 540))

HEADER=$(echo -n '{"alg":"RS256","typ":"JWT"}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
PAYLOAD=$(echo -n "{\"iss\":\"${GITHUB_APP_ID}\",\"iat\":${IAT},\"exp\":${EXP}}" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
SIGNATURE=$(echo -n "${HEADER}.${PAYLOAD}" | openssl dgst -sha256 -sign "$GITHUB_APP_PRIVATE_KEY_PATH" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
JWT="${HEADER}.${PAYLOAD}.${SIGNATURE}"

# Exchange JWT for installation token
RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer ${JWT}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app/installations/${GITHUB_INSTALLATION_ID}/access_tokens")

TOKEN=$(echo "$RESPONSE" | jq -r '.token // empty')
EXPIRES_AT=$(echo "$RESPONSE" | jq -r '.expires_at // empty')

if [[ -z "$TOKEN" ]]; then
  echo "WARNING: Failed to generate GitHub App token" >&2
  echo "$RESPONSE" >&2
  exit 0  # Fail-safe: don't block session
fi

# Write token to file (readable only by user)
echo "$TOKEN" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"

# Write metadata
echo "$EXPIRES_AT" > "${TOKEN_FILE}.meta"

echo "GitHub App token generated (expires: ${EXPIRES_AT})"
```

### Component 2: MCP Server

**Purpose**: Keeps the token fresh by running a background refresh loop, and exposes tools for agents to check token status.

**Implementation**: Lightweight stdio MCP server in bash (or TypeScript).

**Refresh loop**: The MCP server's initialization spawns a background refresh process that:

1. Sleeps for 50 minutes (tokens are valid for 60 minutes, refresh with 10-minute buffer)
2. Regenerates JWT and exchanges for new installation token
3. Writes new token to the shared file
4. Repeats until the MCP server is stopped

**Exposed tools**:

| Tool                   | Description                            | Parameters | Returns                                                                          |
| :--------------------- | :------------------------------------- | :--------- | :------------------------------------------------------------------------------- |
| `get-github-token`     | Get the current valid GitHub App token | none       | Token string                                                                     |
| `refresh-github-token` | Force an immediate token refresh       | none       | New token + expiry                                                               |
| `token-status`         | Check token health and expiry          | none       | `{ valid: bool, expires_at: string, app_id: string, minutes_remaining: number }` |

**Why an MCP server instead of just a hook?**

1. **Continuous refresh**: Hooks only fire on events. There's no periodic hook. An MCP server runs continuously alongside the session.
2. **Tools for agents**: Agents can check token status or force refresh when they get auth errors.
3. **Shared state**: The MCP server owns the token file, preventing race conditions from multiple refresh attempts.

### Token Distribution to Agents

**For agent teams** (tmux panes), the token must be accessible to all agents:

**Option A: Shared file** (recommended)

- Token written to `~/.config/agent/github-token`
- Git credential helper reads from this file
- `gh` CLI configured via `GH_TOKEN` pointing to file: `export GH_TOKEN=$(cat ~/.config/agent/github-token)`

**Option B: Environment variable**

- Less ideal because env vars are set at process start and can't be updated
- Would require agents to re-read from file anyway

**Git credential helper** (`~/.config/agent/git-credential-github-app.sh`):

```bash
#!/usr/bin/env bash
# Git credential helper that reads from the token file
TOKEN_FILE="${GITHUB_TOKEN_FILE:-$HOME/.config/agent/github-token}"
if [[ -f "$TOKEN_FILE" ]]; then
  echo "protocol=https"
  echo "host=github.com"
  echo "username=x-access-token"
  echo "password=$(cat "$TOKEN_FILE")"
fi
```

Configure via: `git config --global credential.https://github.com.helper '!~/.config/agent/git-credential-github-app.sh'`

### Plugin Structure

```
plugins/github-token-refresh/
├── .claude-plugin/
│   └── plugin.json
├── hooks/
│   └── github-token-init.sh          # SessionStart hook
├── mcp/
│   └── token-refresh-server.sh       # MCP server (bash stdio)
├── bin/
│   ├── generate-jwt.sh               # JWT generation helper
│   ├── refresh-token.sh              # Token refresh helper
│   └── git-credential-github-app.sh  # Git credential helper
└── README.md
```

**`plugin.json`**:

```json
{
  "name": "github-token-refresh",
  "version": "0.1.0",
  "description": "Automatic GitHub App token refresh for long-running Claude Code sessions",
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/hooks/github-token-init.sh"
      }
    ]
  },
  "mcpServers": {
    "github-token": {
      "command": "${CLAUDE_PLUGIN_ROOT}/mcp/token-refresh-server.sh",
      "args": []
    }
  }
}
```

### Configuration

Plugin config via `.claude/github-token-refresh.local.md`:

```yaml
---
github_app_id: "12345"
github_installation_id: "67890"
private_key_path: "~/.config/agent/github-app.pem"
token_file: "~/.config/agent/github-token"
refresh_interval_minutes: 50
---
```

Or via environment variables (higher priority):

- `GITHUB_APP_ID`
- `GITHUB_APP_PRIVATE_KEY_PATH`
- `GITHUB_INSTALLATION_ID`
- `GITHUB_TOKEN_FILE`

### Phases

| Phase    | Scope                                                                    | Deliverable                      |
| :------- | :----------------------------------------------------------------------- | :------------------------------- |
| **v0.1** | SessionStart hook generates initial token, writes to file                | Token available at session start |
| **v0.2** | MCP server with background refresh loop + `token-status` tool            | Continuous token freshness       |
| **v0.3** | Git credential helper, `gh` CLI integration, agent team distribution     | Seamless git/gh auth             |
| **v0.4** | Multiple token sources (PAT rotation, org-level apps), per-agent scoping | Advanced identity management     |

### Open Questions

1. **Can a SessionStart hook set environment variables for the session?** If hooks run in a subprocess, `export GITHUB_TOKEN=...` won't affect the parent Claude Code process. May need to rely on the file-based approach exclusively.

2. **MCP server lifecycle**: Does Claude Code keep MCP servers running for the entire session? If the MCP server crashes, does it restart? Need to verify reliability for the background refresh loop.

3. **Race conditions in team mode**: Multiple agents might try to use the token file simultaneously. File reads are atomic on most filesystems, but the write-during-read case needs consideration. A `.lock` file or atomic rename pattern may be needed.

4. **PEM key security**: The PEM file is the most sensitive credential. Should the plugin validate file permissions (must be 600)? Should it support encrypted PEM files with passphrase?

5. **Should this integrate with the agent-github-auth spec?** The auth spec defines Tier 2 (GitHub App). This plugin implements the runtime token management for that tier. They should cross-reference each other.

6. **Fallback behavior**: If GitHub App auth fails, should the plugin fall back to the user's existing `GITHUB_TOKEN` or `gh auth` token? Or should it warn and let the user decide?

### References

- [GitHub App Installation Tokens — GitHub Docs](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [GitHub App JWT Authentication — GitHub Docs](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-json-web-token-jwt-for-a-github-app)
- [Git Credential Helpers — Git Docs](https://git-scm.com/docs/gitcredentials)
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Claude Code Plugins Reference](https://code.claude.com/docs/en/plugins-reference)
  <!-- TODO: Link to agent-github-auth spec once migrated from claude-utils -->
  <!-- TODO: Link to plugin hot-reload research once migrated from claude-utils -->
