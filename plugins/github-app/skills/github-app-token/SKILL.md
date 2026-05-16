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
  │   ├─ Reads GITHUB_APP_ID, GITHUB_INSTALLATION_ID, GITHUB_APP_PRIVATE_KEY
  │   ├─ Materializes PEM to $CLAUDE_PLUGIN_DATA/github-app.pem
  │   ├─ Generates JWT from PEM key
  │   ├─ Exchanges JWT for installation token (1 hour validity)
  │   ├─ Writes token to $CLAUDE_PLUGIN_DATA/github-token
  │   ├─ Creates runtime env file ($CLAUDE_PLUGIN_DATA/github-app-env)
  │   ├─ Sources env file via CLAUDE_ENV_FILE
  │   ├─ Configures git identity (bot user)
  │   └─ Prints: app name, expiry time, env var names
  │
  └─ PreToolUse Hook (github-token-check.sh)
      ├─ Debounced: checks at most every 300 seconds (5 minutes)
      ├─ For gh/git commands: synchronous check
      │   ├─ Valid + >45min: silent allow
      │   ├─ Valid + <45min: allow + background refresh
      │   └─ Expired: synchronous refresh, then allow
      ├─ For other tools: async background check
      ├─ Retries up to 3x with exponential backoff
      └─ 5-minute cooldown after all retries fail
```

### Token Lifecycle

1. **Generation**: JWT created from App private key (10-min validity)
2. **Exchange**: JWT exchanged for installation token via GitHub API
3. **Storage**: Token written to `$CLAUDE_PLUGIN_DATA/github-token` (permissions 600)
4. **Monitoring**: PreToolUse hook checks expiry before each tool call (debounced)
5. **Refresh**: When within 45 min of expiry, token is regenerated
6. **Expiry**: Tokens valid for 1 hour; refreshed with 45-minute buffer

## Setup

### Prerequisites

1. A GitHub App created at `https://github.com/settings/apps`
2. The App's private key (PEM content)
3. The App installed on the target account/organization
4. The installation ID (found in App settings > Installations)

### Configuration

Set these three env vars before the session starts:

- `GITHUB_APP_ID`
- `GITHUB_INSTALLATION_ID`
- `GITHUB_APP_PRIVATE_KEY` (PEM content, not a file path)

**Recommended**: Use the **1pass plugin** to inject from 1Password by adding the three vars to your agent's `1pass.secrets` list in `plugins.settings.yaml`:

```yaml
1pass:
  secrets:
    - envVar: GITHUB_APP_ID
      reference: "op://vault/github-app--repo--my-repo/GITHUB_APP_ID"
    - envVar: GITHUB_INSTALLATION_ID
      reference: "op://vault/github-app--repo--my-repo/GITHUB_INSTALLATION_ID"
    - envVar: GITHUB_APP_PRIVATE_KEY
      reference: "op://vault/github-app--repo--my-repo/GITHUB_APP_PRIVATE_KEY"

github-app:
  enabled: true
  autoGitConfig: true
```

Any other mechanism that exports these vars into the session env works (direct shell export, `.env` file sourced before launch, etc.).

The plugin materializes the PEM to `$CLAUDE_PLUGIN_DATA/github-app.pem` on every session start. No pre-existing PEM file is needed.

## Checking Token Status

Run the token status script directly:

```bash
$CLAUDE_PLUGIN_ROOT/bin/token-status.sh
```

Or check the metadata file (length-only — never print the raw token):

```bash
jq '.expires_at' "$CLAUDE_PLUGIN_DATA/github-token.meta"
```

## Manually Refreshing the Token

### Option A — Use token-check.sh (preferred)

```bash
$CLAUDE_PLUGIN_ROOT/bin/token-check.sh --sync
```

Exit codes: `0` = valid/refreshed, `1` = failed after retries, `2` = not configured, `3` = cooldown.

### Option B — Call generate-token.sh directly

**Step 1 — Verify env vars (length-only, never print values)**

```bash
for v in GITHUB_APP_ID GITHUB_INSTALLATION_ID GITHUB_APP_PRIVATE_KEY; do
  val="${!v:-}"
  [[ -n "$val" ]] && echo "$v is set (${#val} chars)" || echo "$v is NOT set"
done
```

**Step 2 — Run generate-token.sh**

The PEM is already at `$CLAUDE_PLUGIN_DATA/github-app.pem` (materialized by SessionStart).

```bash
$CLAUDE_PLUGIN_ROOT/bin/generate-token.sh \
  "$GITHUB_APP_ID" \
  "$CLAUDE_PLUGIN_DATA/github-app.pem" \
  "$GITHUB_INSTALLATION_ID" \
  "$CLAUDE_PLUGIN_DATA/github-token"
```

**Step 3 — Verify**

```bash
GH_TOKEN=$(cat "$CLAUDE_PLUGIN_DATA/github-token") gh api /user --jq '.login'
# Expected: <app-slug>[bot]
```

### Common failures

| Symptom                              | Likely cause                                              |
| ------------------------------------ | --------------------------------------------------------- |
| `HTTP 401` during JWT exchange       | PEM key mismatch or clock skew > 60s                      |
| `HTTP 404` on `/app/installations/…` | Wrong `GITHUB_INSTALLATION_ID`                            |
| `Failed to sign JWT`                 | PEM content malformed or `GITHUB_APP_PRIVATE_KEY` missing |
| `exit 2` from token-check.sh         | Credential env vars missing                               |
| `exit 3` from token-check.sh         | 5-min cooldown — wait or clear `.cooldown` file           |

## Git Credential Helper

The SessionStart hook configures git to use `gh auth git-credential` directly. The gitconfig entry written is:

```ini
[credential "https://github.com"]
    helper =
    helper = !gh auth git-credential
```

## Troubleshooting

### "GitHub App not configured"

Missing env vars. Check lengths (never print values):

```bash
for v in GITHUB_APP_ID GITHUB_INSTALLATION_ID GITHUB_APP_PRIVATE_KEY; do
  val="${!v:-}"; [[ -n "$val" ]] && echo "$v set (${#val} chars)" || echo "$v NOT SET"
done
```

### "in cooldown period"

Clear the cooldown:

```bash
rm "$CLAUDE_PLUGIN_DATA/github-token.cooldown"
```

### Cleanup of old v0.3.x paths

v0.4.0 writes everything under `$CLAUDE_PLUGIN_DATA/`. Orphaned files at `~/.agents/<name>/.config/` can be removed:

```bash
rm -rf ~/.agents/<name>/.config/github-token* ~/.agents/<name>/.config/github-app-env \
       ~/.agents/<name>/.config/github-app.pem ~/.agents/<name>/.config/github-git-identity
```

## Related

- **[github](../github)** plugin — GitHub CLI and general authentication skills
- The `github-auth` skill covers all auth methods
