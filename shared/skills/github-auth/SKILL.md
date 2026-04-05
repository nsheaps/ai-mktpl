---
name: github-auth
description: >
  Guide Claude through GitHub authentication methods including device code flow,
  personal access tokens, fine-grained tokens, and GitHub App authorization.
  Use when the user needs to authenticate with GitHub for CLI operations,
  API access, cross-repo work, or automated workflows.
  <example>authenticate with github</example>
  <example>I need to create a PR in another repo</example>
  <example>gh auth login</example>
  <example>set up a personal access token</example>
  <example>configure github app authentication</example>
---

# GitHub Authentication Skill

This skill covers all GitHub authentication methods relevant to Claude Code sessions. It enables Claude to guide users through the appropriate auth flow for their use case.

## When Claude Activates This Skill

- **Permission Errors**: Claude encounters 403/404 errors accessing GitHub resources
- **Cross-Repository Actions**: User needs Claude to interact with repos outside the current workspace
- **GitHub API Access Required**: Operations requiring authentication
- **Token Setup**: User asks to configure GitHub tokens or app credentials
- **CI/CD Authentication**: Setting up automated auth for pipelines or agent sessions

## Authentication Methods Overview

| Method                          | Best For                 | Expires                     | Scope Control      |
| ------------------------------- | ------------------------ | --------------------------- | ------------------ |
| Device Code Flow                | Interactive CLI sessions | Session-based               | Per-login          |
| Personal Access Token (classic) | Simple automation, CI    | Configurable / never        | Broad scopes       |
| Fine-Grained PAT                | Targeted repo access     | Configurable (max 1yr)      | Per-repo, granular |
| GitHub App (as app)             | Automated systems, bots  | 1 hour (installation token) | Per-installation   |
| GitHub App (as user)            | User-to-server, OAuth    | Session-based               | Per-authorization  |

## Method 1: Device Code Flow (Interactive)

Best for: Claude Code sessions where the user is present and can authorize in a browser.

### Process

```bash
BROWSER=false gh auth login
```

This outputs:

- A one-time code (e.g., `ABCD-1234`)
- A URL: `https://github.com/login/device`

The user visits the URL, enters the code, and authorizes access.

### With Options

```bash
# GitHub.com with HTTPS
BROWSER=false gh auth login --hostname github.com --git-protocol https

# With specific scopes
BROWSER=false gh auth login --scopes "repo,read:org,write:packages"

# GitHub Enterprise
BROWSER=false gh auth login --hostname github.mycompany.com
```

### Common Scopes

| Scope              | Description                            |
| ------------------ | -------------------------------------- |
| `repo`             | Full control of private repositories   |
| `read:org`         | Read organization membership           |
| `write:org`        | Read and write organization membership |
| `read:packages`    | Download packages from GitHub Packages |
| `write:packages`   | Upload packages to GitHub Packages     |
| `admin:public_key` | Manage public keys                     |
| `gist`             | Create gists                           |
| `workflow`         | Update GitHub Action workflows         |

### Managing Auth State

```bash
# Check current status
gh auth status

# Refresh expired token
BROWSER=false gh auth refresh

# Switch accounts
gh auth switch --user username

# Logout
gh auth logout
```

## Method 2: Personal Access Token (Classic)

Best for: Simple automation, CI pipelines, or when device code flow isn't available.

### Creating a Classic PAT

1. Go to `https://github.com/settings/tokens`
2. Click "Generate new token (classic)"
3. Select scopes needed
4. Set expiration (or no expiration for long-lived automation)
5. Copy the token immediately (shown only once)

### Using with gh CLI

```bash
# Authenticate with token
echo "$GH_TOKEN" | gh auth login --with-token

# Or set as environment variable
export GH_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export GITHUB_TOKEN="$GH_TOKEN"  # Also recognized by git and many tools
```

### Using with Git

```bash
# Via credential helper
git config --global credential.helper store
# Then use token as password when prompted

# Or via URL
git clone https://x-access-token:${GH_TOKEN}@github.com/owner/repo.git
```

### Security Notes

- Classic PATs have broad scope (e.g., `repo` grants access to ALL repos)
- Prefer fine-grained PATs for targeted access
- Set expiration dates when possible
- Store in environment variables or secret managers, never in code

## Method 3: Fine-Grained Personal Access Token

Best for: Targeted access to specific repositories with minimal permissions.

### Creating a Fine-Grained PAT

1. Go to `https://github.com/settings/personal-access-tokens/new`
2. Set token name and expiration (max 1 year)
3. Select **Resource owner** (your account or an org)
4. Choose **Repository access**: All, Public only, or Select repositories
5. Set **Permissions** per category (granular control)
6. Generate and copy

### Key Differences from Classic PATs

- Scoped to specific repositories
- Granular permissions (e.g., "Issues: Read" vs broad "repo" scope)
- Maximum 1-year expiration (no "never expires")
- Organization owners can require approval
- Can be restricted to a single repository

### Permission Categories

- **Repository permissions**: Actions, Contents, Issues, Pull requests, etc.
- **Account permissions**: Profile, Email, SSH keys, etc.
- **Organization permissions**: Members, Projects, etc.

### Usage

Same as classic PATs — set `GH_TOKEN` or `GITHUB_TOKEN` environment variable.

## Method 4: GitHub App Authorization

Best for: Automated systems, bot identities, long-running agent sessions.

### Authenticating as the App (Server-to-Server)

GitHub Apps authenticate using a two-step process:

1. **Generate JWT** from the App's private key (valid 10 minutes)
2. **Exchange JWT** for an installation access token (valid 1 hour)

```bash
# Step 1: Generate JWT
NOW=$(date +%s)
IAT=$((NOW - 60))
EXP=$((NOW + 540))

HEADER=$(echo -n '{"alg":"RS256","typ":"JWT"}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
PAYLOAD=$(echo -n "{\"iss\":\"${GITHUB_APP_ID}\",\"iat\":${IAT},\"exp\":${EXP}}" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
SIGNATURE=$(echo -n "${HEADER}.${PAYLOAD}" | openssl dgst -sha256 -sign "$GITHUB_APP_PRIVATE_KEY_PATH" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
JWT="${HEADER}.${PAYLOAD}.${SIGNATURE}"

# Step 2: Exchange for installation token
curl -s -X POST \
  -H "Authorization: Bearer ${JWT}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app/installations/${GITHUB_INSTALLATION_ID}/access_tokens"
```

### Required Environment Variables

| Variable                      | Description                                |
| ----------------------------- | ------------------------------------------ |
| `GITHUB_APP_ID`               | The GitHub App's numeric ID                |
| `GITHUB_APP_PRIVATE_KEY_PATH` | Path to PEM private key file               |
| `GITHUB_INSTALLATION_ID`      | Installation ID for the target account/org |

### Installation Token Limitations

- Expires after **1 hour** (non-configurable)
- Scoped to the repositories the App is installed on
- Permissions defined by the App's configuration
- Cannot be refreshed — must generate a new one

### Using Installation Tokens

```bash
# With gh CLI
export GH_TOKEN="ghs_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# With git
git config credential.https://github.com.helper \
  '!f() { echo "protocol=https"; echo "host=github.com"; echo "username=x-access-token"; echo "password=${GH_TOKEN}"; }; f'
```

### Authenticating as a User (User-to-Server)

GitHub Apps can also act on behalf of a user via OAuth:

1. User visits: `https://github.com/login/oauth/authorize?client_id=APP_CLIENT_ID`
2. User authorizes the app
3. App receives a user access token
4. Token has intersection of app permissions AND user permissions

This is useful when the app needs to act as a specific user rather than as itself.

## Choosing the Right Method

### Decision Flow

1. **Is a user present and interactive?**
   - Yes → Device Code Flow (Method 1)
   - No → Continue

2. **Do you need access to specific repos only?**
   - Yes → Fine-Grained PAT (Method 3) or GitHub App (Method 4)
   - No → Continue

3. **Is this for a long-running automated system?**
   - Yes → GitHub App (Method 4) — handles token rotation
   - No → Classic PAT (Method 2) is simplest

4. **Do you need a bot identity (not a user)?**
   - Yes → GitHub App (Method 4)
   - No → PAT (Method 2 or 3)

## Security Best Practices

1. **Minimal permissions**: Request only the scopes/permissions needed
2. **Set expiration**: Use the shortest practical token lifetime
3. **Secure storage**: Never commit tokens to code; use env vars or secret managers
4. **PEM key protection**: GitHub App private keys should be `chmod 600`
5. **Audit regularly**: Review authorized apps at `https://github.com/settings/applications`
6. **Rotate tokens**: Change tokens periodically, especially after team changes
7. **Use SSO**: For org repos, authorize SSO after authenticating

## Error Reference

| Error                    | Cause                            | Solution                                |
| ------------------------ | -------------------------------- | --------------------------------------- |
| `HTTP 401`               | Token expired or invalid         | Re-authenticate or generate new token   |
| `HTTP 403`               | Insufficient permissions         | Check scopes; re-authenticate with more |
| `HTTP 404`               | Private repo, not authenticated  | Authenticate to access private repos    |
| `SSO Required`           | Organization requires SSO        | Authorize SSO in browser settings       |
| `Bad credentials`        | Token revoked or malformed       | Re-authenticate from scratch            |
| `JWT expired`            | GitHub App JWT older than 10 min | Regenerate JWT and retry                |
| `Installation suspended` | App installation was suspended   | Contact org admin                       |

## Token Storage Locations

| Method                 | Storage Location                            |
| ---------------------- | ------------------------------------------- |
| `gh auth login`        | `~/.config/gh/hosts.yml`                    |
| `GH_TOKEN` env var     | Process environment                         |
| `GITHUB_TOKEN` env var | Process environment                         |
| GitHub App token file  | `~/.config/agent/github-token` (convention) |
| Git credential helper  | OS keychain or `~/.git-credentials`         |

## SSO Authorization

For organizations requiring SAML SSO:

1. Authenticate normally (any method above)
2. Visit `https://github.com/settings/applications`
3. Find the authorized application
4. Click "Configure SSO" next to your organization
5. Authorize the organization
