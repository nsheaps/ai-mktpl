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
Session Start
  │
  ├─ SessionStart Hook (github-token-init.sh)
  │   ├─ Reads GITHUB_APP_ID, PRIVATE_KEY_PATH, INSTALLATION_ID
  │   ├─ Generates JWT from PEM key
  │   ├─ Exchanges JWT for installation token (1 hour validity)
  │   ├─ Writes token to ~/.config/agent/github-token
  │   ├─ Creates runtime env file (~/.config/agent/github-app-env)
  │   ├─ Sources env file via CLAUDE_ENV_FILE
  │   ├─ Configures git identity (bot user)
  │   └─ Prints: app name, expiry time, env var names
  │
  └─ PreToolUse Hook (github-token-check.sh)
      ├─ Debounced: checks at most every 30 seconds
      ├─ For gh/git commands: synchronous check
      │   ├─ Valid + >30min: silent allow
      │   ├─ Valid + <30min: allow + background refresh
      │   └─ Expired: synchronous refresh, then allow
      ├─ For other tools: async background check
      ├─ Retries up to 3x with exponential backoff
      └─ 5-minute cooldown after all retries fail
```

### Token Lifecycle

1. **Generation**: JWT created from App private key (10-min validity)
2. **Exchange**: JWT exchanged for installation token via GitHub API
3. **Storage**: Token written to `~/.config/agent/github-token` (permissions 600)
4. **Monitoring**: PreToolUse hook checks expiry before each tool call (debounced)
5. **Refresh**: When within 30 min of expiry, token is regenerated
6. **Expiry**: Tokens valid for 1 hour; refreshed with 30-minute buffer

## Setup

### Prerequisites

1. A GitHub App created at `https://github.com/settings/apps`
2. The App's private key (PEM file) downloaded
3. The App installed on the target account/organization
4. The installation ID (found in App settings > Installations)

### Configuration

The plugin supports multiple secret sources. Each value can be a literal, `${ENV_VAR}`, or `op://vault/item/field`.

#### Option A: Bulk Secret Reference (`ref`)

Use `ref` to load all secrets from one source:

```yaml
# In $CLAUDE_PROJECT_DIR/.claude/plugins.settings.yaml
github-app:
  # 1Password item (uses op-exec from nsheaps/op-exec)
  ref: "op://vault/github-app--repo--my-repo"
  # Or an env file with KEY=VALUE pairs
  # ref: "env-file://./.env.github-app"
```

Expected field names: `GITHUB_APP_ID`, `GITHUB_APP_CLIENT_ID`, `GITHUB_APP_CLIENT_SECRET`, `GITHUB_APP_PRIVATE_KEY`, `GITHUB_INSTALLATION_ID`.

#### Option B: Individual Secret References

```yaml
github-app:
  secrets:
    github_app_id: "op://vault/item/GITHUB_APP_ID"
    github_app_private_key: "op://vault/item/GITHUB_APP_PRIVATE_KEY"
    github_installation_id: "${GITHUB_INSTALLATION_ID}"
```

#### Option C: Environment Variables

```bash
export GITHUB_APP_ID="12345"
export GITHUB_APP_PRIVATE_KEY_PATH="~/.config/agent/github-app.pem"
export GITHUB_INSTALLATION_ID="67890"
```

### Private Key Handling

The private key can be provided as:

- **File path** (`private_key_path` / `GITHUB_APP_PRIVATE_KEY_PATH`): PEM file on disk
- **Key content** (`secrets.github_app_private_key` / `GITHUB_APP_PRIVATE_KEY`): PEM content directly (e.g., from 1Password). Written to a secure temp file automatically.

### PEM Key Security

```bash
# Ensure correct permissions
chmod 600 ~/.config/agent/github-app.pem

# Verify the key
openssl rsa -in ~/.config/agent/github-app.pem -check -noout
```

## Checking Token Status

Run the token status script directly:

```bash
~/.config/agent/github-app-env  # source to get vars
$CLAUDE_PLUGIN_ROOT/bin/token-status.sh
```

Or check the metadata file:

```bash
cat ~/.config/agent/github-token.meta | jq .
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

## Agent Team Usage

For agent teams (tmux panes), all agents share the same token file:

- Token file: `~/.config/agent/github-token`
- All agents read from the same file
- PreToolUse hook in each agent monitors and refreshes as needed
- File-based locking prevents concurrent refresh races

## Troubleshooting

### "GitHub App not configured"

Missing one or more required environment variables. Set all three:

- `GITHUB_APP_ID`
- `GITHUB_APP_PRIVATE_KEY_PATH`
- `GITHUB_INSTALLATION_ID`

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

Check that the runtime env file exists and is being sourced:

```bash
cat ~/.config/agent/github-app-env
```

If missing, the SessionStart hook may have failed. Check stderr output from session start.

### "in cooldown period"

The plugin failed to refresh 3 times consecutively and is backing off for 5 minutes. Check:

1. Network connectivity
2. GitHub API status
3. App credentials validity

To clear the cooldown manually:

```bash
rm ~/.config/agent/github-token.cooldown
```

### Permissions Issues

Installation tokens inherit the App's configured permissions. If you get 403 errors:

1. Check the App's permission configuration in GitHub settings
2. Verify the App is installed with the needed permissions
3. Org owners may need to approve permission changes

## Related

- **[github](../github)** plugin — GitHub CLI and general authentication skills
- The `github-auth` skill (shared between both plugins) covers all auth methods
