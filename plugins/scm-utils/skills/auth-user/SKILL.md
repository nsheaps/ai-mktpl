---
name: auth-user
description: Identify the authenticated user for GitHub CLI (gh) and Git
argument-hint: [gh|git|ssh|all]
---

# Identify Authenticated User

This skill helps identify which user account is authenticated for GitHub CLI (`gh`) and Git operations. Use this to troubleshoot authentication issues, verify the correct account is in use, or understand how credentials are configured.

## Quick Reference

| Method             | Command                       | Shows                              |
| ------------------ | ----------------------------- | ---------------------------------- |
| GitHub CLI         | `gh auth status`              | Active gh account, auth method     |
| HTTPS credentials  | `git credential fill`         | Stored username/password for HTTPS |
| SSH connection     | `ssh -T git@github.com`       | SSH key owner                      |
| Token verification | `GH_TOKEN=... gh auth status` | Token owner                        |

## GitHub CLI (`gh`)

### Check Current Authentication Status

```bash
gh auth status
```

**Example output:**

```
github.com
  ✓ Logged in to github.com account octocat (/home/user/.config/gh/hosts.yml)
  - Active account: true
  - Git operations protocol: https
  - Token: ghp_************************************
  - Token scopes: 'gist', 'read:org', 'repo', 'workflow'
```

### Check Specific Hostname (GitHub Enterprise)

```bash
gh auth status --hostname github.example.com
```

### View gh Configuration

```bash
gh config list
```

Shows settings like `git_protocol`, `editor`, and `prompt`.

### Identify Token Owner

To see who a specific token belongs to:

```bash
GH_TOKEN="your_token_here" gh auth status
```

This is useful when you have a token (e.g., from environment variables or CI) and need to verify which account it authenticates as.

### Get Just the Token

```bash
gh auth token
```

Returns the raw token for the current account.

## Git Credentials (HTTPS)

### Check Stored HTTPS Credentials

```bash
echo "protocol=https
host=github.com" | git credential fill
```

**Example output:**

```
protocol=https
host=github.com
username=octocat
password=ghp_xxxxxxxxxxxxxxxxxxxx
```

### Check Credentials for Other Hosts

```bash
echo "protocol=https
host=gitlab.com" | git credential fill
```

### Using URL Format

```bash
echo "url=https://github.com" | git credential fill
```

### Where Credentials Are Stored

Credentials may be stored in different locations depending on the credential helper:

| Helper         | Storage Location                 |
| -------------- | -------------------------------- |
| `store`        | `~/.git-credentials` (plaintext) |
| `cache`        | In-memory (temporary)            |
| `osxkeychain`  | macOS Keychain                   |
| `manager`      | Windows Credential Manager       |
| `manager-core` | Git Credential Manager           |

Check configured helper:

```bash
git config --get credential.helper
```

## SSH Authentication

### Test SSH Connection to GitHub

```bash
ssh -T git@github.com
```

**Successful output:**

```
Hi octocat! You've successfully authenticated, but GitHub does not provide shell access.
```

The username shown is the GitHub account associated with your SSH key.

### Test with Verbose Output

```bash
ssh -vT git@github.com
```

Shows which key file is being used for authentication.

### Test Other Git Hosts

```bash
# GitLab
ssh -T git@gitlab.com
# Output: Welcome to GitLab, @username!

# Bitbucket
ssh -T git@bitbucket.org
# Output: authenticated via ssh key.
```

### Check SSH Credentials via Git

```bash
echo "protocol=ssh
host=github.com" | git credential fill
```

Note: SSH typically uses key-based auth, so this may not return credentials.

## Common Troubleshooting

### Multiple Accounts

If you have multiple GitHub accounts:

```bash
# List all authenticated accounts
gh auth status

# Switch between accounts
gh auth switch
```

### Credential Conflicts

When HTTPS and SSH credentials point to different accounts:

1. Check which protocol Git is using:

   ```bash
   git config --get remote.origin.url
   ```

2. URLs starting with `https://` use HTTPS credentials
3. URLs starting with `git@` use SSH keys

### Token Scopes

To see what permissions a token has:

```bash
gh auth status
```

Look for "Token scopes" in the output.

## Process

Based on the argument ($ARGUMENTS), check the relevant authentication method:

1. **`gh` or no argument**: Run `gh auth status` and `gh config list`
2. **`git` or `https`**: Run the `git credential fill` command for HTTPS
3. **`ssh`**: Run `ssh -T git@github.com`
4. **`all`**: Run all checks and summarize which accounts are configured

After running commands, summarize:

- The authenticated username(s)
- The authentication method (token, SSH key, etc.)
- Any mismatches between different auth methods
