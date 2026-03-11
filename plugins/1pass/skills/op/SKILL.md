---
name: op
description: >
  Use this skill when the user asks about 1Password, secrets management,
  retrieving credentials, using op CLI, service accounts, secret references,
  vault operations, or any task involving the 1Password CLI (op). Also use
  when needing to inject secrets into environment variables, read passwords
  or API keys from 1Password, or manage 1Password items from the command line.
---

# op - 1Password CLI

The 1Password CLI (`op`) lets you manage 1Password vaults, items, and secrets
from the terminal. It integrates with shell environments to securely inject
secrets without exposing them in plaintext.

## Quick Reference

### Authentication

```bash
# Check sign-in status
op whoami

# Sign in (interactive)
op signin

# Sign in with service account token (CI/automation)
export OP_SERVICE_ACCOUNT_TOKEN="your-token"
op whoami

# List accounts
op account list
```

### Core Commands

| Command           | Description                         |
| ----------------- | ----------------------------------- |
| `op item list`    | List items in a vault               |
| `op item get`     | Get item details                    |
| `op item create`  | Create a new item                   |
| `op item edit`    | Edit an existing item               |
| `op item delete`  | Delete an item                      |
| `op vault list`   | List vaults                         |
| `op vault get`    | Get vault details                   |
| `op read`         | Read a secret reference             |
| `op inject`       | Inject secrets into a template      |
| `op run`          | Run a command with secrets injected |
| `op whoami`       | Show current user/account           |
| `op document get` | Download a document                 |

## Secret References

1Password secret references use the format:
`op://vault-name/item-name/field-name`

```bash
# Read a single secret
op read "op://Private/My API Key/credential"

# Read a password
op read "op://Private/My Login/password"

# Read a specific section field
op read "op://Private/Server Config/database/connection_string"
```

## Injecting Secrets

### Into Environment Variables

```bash
# Run a command with secrets injected from env template
export DB_PASSWORD="op://Private/Database/password"
export API_KEY="op://Private/API Key/credential"
op run -- my-command

# Run with env file
op run --env-file .env -- my-command
```

### Into Config Files

```bash
# Inject secrets into a template file
op inject -i config.template.yaml -o config.yaml

# Template syntax in files:
# database:
#   password: {{ op://Private/Database/password }}
```

## Item Management

### Listing Items

```bash
# List all items
op item list

# List items in a specific vault
op item list --vault "Private"

# List with format
op item list --format json

# Filter by category
op item list --categories "Login"
op item list --categories "API Credential"
op item list --categories "Secure Note"

# Filter by tag
op item list --tags "production"
```

### Getting Items

```bash
# Get full item details
op item get "My Login" --vault "Private"

# Get specific field
op item get "My Login" --fields "password"

# Get as JSON
op item get "My Login" --format json

# Get by UUID
op item get "abc123def456"

# Get OTP code
op item get "My Login" --otp
```

### Creating Items

```bash
# Create a login
op item create --category login \
  --title "New Service" \
  --vault "Private" \
  --url "https://example.com" \
  username="admin" \
  password="secret123"

# Create an API credential
op item create --category "API Credential" \
  --title "Service API Key" \
  --vault "Private" \
  credential="sk-abc123"

# Create a secure note
op item create --category "Secure Note" \
  --title "Important Note" \
  --vault "Private" \
  notesPlain="This is the note content"

# Generate a random password for new item
op item create --category login \
  --title "New Account" \
  --generate-password="20,letters,digits,symbols"
```

### Editing Items

```bash
# Edit a field
op item edit "My Login" --vault "Private" \
  password="new-password"

# Add a tag
op item edit "My Login" --tags "production,critical"
```

## Vault Management

```bash
# List vaults
op vault list

# Get vault details
op vault get "Private"

# Create a vault
op vault create "Team Secrets"

# List vault permissions
op vault user list "Private"
```

## Service Accounts

Service accounts are used for CI/CD and automation:

```bash
# Set the token
export OP_SERVICE_ACCOUNT_TOKEN="ops_..."

# Use op normally — it auto-authenticates
op read "op://vault/item/field"
op run -- my-command
```

Service account limitations:

- Can only access vaults explicitly granted
- Cannot create/delete vaults
- Cannot manage users or groups
- Read-only by default (write access must be granted)

## Common Workflows

### Inject Secrets into Environment

```bash
# .env file with secret references
# DATABASE_URL=op://Private/DB/connection_string
# API_KEY=op://Private/API/credential

op run --env-file .env -- docker compose up
```

### Use in Scripts

```bash
#!/bin/bash
DB_PASS=$(op read "op://Private/Database/password")
API_KEY=$(op read "op://Private/API Key/credential")

curl -H "Authorization: Bearer $API_KEY" https://api.example.com
```

### Generate Passwords

```bash
# Generate a random password
op item create --category password --generate-password

# Custom password recipe
op item create --category password \
  --generate-password="30,letters,digits,symbols"
```

## Plugin Settings

This plugin supports configuration via `plugins.settings.yaml`:

```yaml
1pass:
  enabled: true
  auto_install: false # Download op if not on PATH
  install_to_project: true # Install to $project/bin/.local
  background_install: false # Install in background
  op_version: "latest" # Specific op version or "latest"
  install_op_exec: false # Also install op-exec
  op_exec_version: "latest" # Specific op-exec version
```

Place in:

- `$CLAUDE_PROJECT_DIR/.claude/plugins.settings.yaml` (project-level)
- `~/.claude/plugins.settings.yaml` (user-level)

## Environment Variables

| Variable                   | Description                              |
| -------------------------- | ---------------------------------------- |
| `OP_SERVICE_ACCOUNT_TOKEN` | Service account token for authentication |
| `OP_CONNECT_HOST`          | 1Password Connect server URL             |
| `OP_CONNECT_TOKEN`         | 1Password Connect API token              |
| `OP_ACCOUNT`               | Default account shorthand                |
| `OP_VAULT`                 | Default vault                            |

## Troubleshooting

### "op: command not found"

Ensure op is installed. This plugin auto-installs to `$CLAUDE_PROJECT_DIR/bin/.local/op`
when `auto_install: true`. Alternatively, install via mise:

```toml
# mise.toml
[tools]
"vfox:mise-plugins/vfox-1password" = "latest"
```

### Authentication errors

```bash
# Verify sign-in
op whoami

# Re-authenticate
op signin

# Check service account token
echo $OP_SERVICE_ACCOUNT_TOKEN | head -c 10
```

### "You are not currently signed in"

In CI/web sessions, use a service account token:

```bash
export OP_SERVICE_ACCOUNT_TOKEN="ops_..."
```
