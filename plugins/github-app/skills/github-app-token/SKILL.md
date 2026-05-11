---
name: github-app-token
description: >
  Manage GitHub App installation tokens in Claude Code sessions. Use when
  tokens expire, auth errors occur in long-running sessions, or when setting
  up GitHub App credentials for agent teams.
  <example>my github token expired</example>
  <example>refresh the github app token</example>
  <example>check token status</example>
  <example>set up github app authentication for this session</example>
---

# GitHub App Token Management Skill

This skill covers managing GitHub App installation tokens in Claude Code sessions, including setup, refresh, troubleshooting, and agent team distribution.

## When Claude Activates This Skill

- **Auth errors in long sessions**: Token expired after running for >1 hour
- **Token setup**: User wants to configure GitHub App credentials
- **Status checks**: User asks about token validity or expiry
- **Agent team coordination**: Multiple agents need shared GitHub access

## How Token Refresh Works

### Architecture

```
Launcher (bin/agent)
  │
  ├─ Sources $AGENT_HOME_DIR/.env (and .env.local) before exec'ing claude
  │   → GITHUB_APP_ID, GITHUB_APP_INSTALLATION_ID,
  │     GITHUB_APP_PRIVATE_KEY_PATH are in process env at hook time.
  │
  ▼
Session Start
  │
  ├─ SessionStart Hook (github-token-init.sh)
  │   ├─ Validates required env vars are present (fail-fast — no fallback)
  │   ├─ Generates JWT from PEM key
  │   ├─ Exchanges JWT for installation token (1 hour validity)
  │   ├─ Writes token to ${XDG_CONFIG_HOME}/github-app/token (chmod 600)
  │   ├─ Writes ${XDG_CONFIG_HOME}/github-app/runtime.env (GH_TOKEN/GITHUB_TOKEN)
  │   ├─ Writes ${XDG_CONFIG_HOME}/github-app/git-identity.env (bot identity)
  │   ├─ Appends `source` lines to CLAUDE_ENV_FILE so Bash inherits them
  │   ├─ Configures global gitconfig with credential helper
  │   └─ Logs: app slug, expiry time
  │
  └─ PreToolUse Hook (github-token-check.sh)
      ├─ Throttled: checks at most every 300 seconds (5 minutes)
      ├─ For gh/git commands: synchronous check
      │   ├─ Valid + >45min: silent allow
      │   ├─ Valid + ≤45min: allow + background refresh
      │   └─ Expired/missing: synchronous refresh, then allow
      ├─ For other tools: async background check
      ├─ Retries up to 3x with exponential backoff
      └─ 5-minute cooldown after all retries fail
```

### Token Lifecycle

1. **Generation**: JWT created from App private key (10-min validity)
2. **Exchange**: JWT exchanged for installation token via GitHub API
3. **Storage**: Token written to `${XDG_CONFIG_HOME}/github-app/token` (permissions 600)
4. **Monitoring**: PreToolUse hook checks expiry before each tool call (throttled)
5. **Refresh**: When within 45 min of expiry, token is regenerated
6. **Expiry**: Tokens valid for 1 hour; refreshed with 45-minute buffer

## Setup

### Prerequisites

1. A GitHub App created at `https://github.com/settings/apps`
2. The App's private key (PEM file) downloaded
3. The App installed on the target account/organization
4. The installation ID (found in App settings > Installations)

### Configuration

As of 0.4.0, the plugin no longer resolves secrets itself. The launcher
(`bin/agent`) is responsible for sourcing the agent's `.env` / `.env.local`
chain before exec'ing `claude`, so the following env vars are present at hook
time:

```bash
GITHUB_APP_ID="12345"
GITHUB_APP_INSTALLATION_ID="67890"
GITHUB_APP_PRIVATE_KEY_PATH="${XDG_CONFIG_HOME}/github-app.pem"  # absolute path to PEM on disk
```

The launcher's `.env.local` is typically managed by the 1pass plugin (which
materializes 1Password items to disk). The github-app plugin is decoupled
from any specific secret manager and trusts whatever puts the right env
vars in process env.

If any required var is missing when the SessionStart hook fires, the plugin
fails loudly with a one-line message naming each missing var.

### Private Key Handling

`GITHUB_APP_PRIVATE_KEY_PATH` must point to a PEM file on disk. Inline PEM
content (`GITHUB_APP_PRIVATE_KEY`) is not supported — write the key to disk in
your launcher's env chain.

### PEM Key Security

```bash
# Ensure correct permissions
chmod 600 "${XDG_CONFIG_HOME}/github-app.pem"

# Verify the key
openssl rsa -in "${XDG_CONFIG_HOME}/github-app.pem" -check -noout
```

## Checking Token Status

Source the runtime env file to pick up `GH_TOKEN`/`GITHUB_TOKEN`, then run the
status script:

```bash
source "${XDG_CONFIG_HOME}/github-app/runtime.env"
$CLAUDE_PLUGIN_ROOT/bin/token-status.sh
```

Or check the metadata file:

```bash
jq . "${XDG_CONFIG_HOME}/github-app/token.meta"
```

## Forcing a Token Refresh

```bash
$CLAUDE_PLUGIN_ROOT/bin/token-check.sh --sync
```

## Git Credential Helper

The plugin includes a git credential helper for seamless `git push` operations:

```bash
# Configure git to use the helper
git config --global credential.https://github.com.helper \
  '!/path/to/plugins/github-app/bin/git-credential-github-app.sh'
```

This reads the token from the shared file, so `git push` always uses the latest token.

## Per-Agent Isolation

Each agent gets its own token file under its XDG config root:

- Token file: `${XDG_CONFIG_HOME}/github-app/token` (resolves to
  `$AGENT_HOME_DIR/.config/github-app/token`)
- Each agent has its own SessionStart + PreToolUse hooks and refreshes
  independently — no shared state across agents
- File-based locking prevents concurrent refresh races within a single agent

## Troubleshooting

### "GitHub App not configured"

Missing one or more required environment variables. Set all three:

- `GITHUB_APP_ID`
- `GITHUB_APP_PRIVATE_KEY_PATH`
- `GITHUB_APP_INSTALLATION_ID`

### "PEM key not found"

The private key path doesn't exist or isn't readable. Check the path and permissions.

### "Token exchange failed (HTTP 401)"

The JWT is invalid. Common causes:

- PEM key doesn't match the App ID
- System clock is significantly off (JWT uses time-based claims)
- App has been deleted or suspended

### "Token exchange failed (HTTP 404)"

The installation ID is wrong or the App is no longer installed on the target account.

### "Token expired" or auth errors despite PreToolUse hook

Check that the runtime env file exists and is being sourced. The file holds
`GH_TOKEN`/`GITHUB_TOKEN` exports — list keys only (it does not contain other
secrets, but treat it as sensitive regardless):

```bash
ls -l "${XDG_CONFIG_HOME}/github-app/runtime.env"
```

If missing, the SessionStart hook may have failed. Check stderr output from session start.

### "in cooldown period"

The plugin failed to refresh 3 times consecutively and is backing off for 5 minutes. Check:

1. Network connectivity
2. GitHub API status
3. App credentials validity

To clear the cooldown manually:

```bash
rm "${XDG_CONFIG_HOME}/github-app/token.cooldown"
```

### Permissions Issues

Installation tokens inherit the App's configured permissions. If you get 403 errors:

1. Check the App's permission configuration in GitHub settings
2. Verify the App is installed with the needed permissions
3. Org owners may need to approve permission changes

## Related

- **[github](../github)** plugin — GitHub CLI and general authentication skills
- The `github-auth` skill (shared between both plugins) covers all auth methods
