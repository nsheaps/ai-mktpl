---
name: op-exec
description: >
  Use this skill when the user asks about op-exec, running commands with
  1Password secrets injected, wrapping processes with secret injection,
  automating secret-aware command execution, or configuring whole-item
  environment injection with multiple output targets. op-exec is a wrapper
  around the 1Password CLI that simplifies running commands with secrets
  from 1Password vaults.
---

# op-exec - 1Password Secret Injection Wrapper

`op-exec` (from [nsheaps/op-exec](https://github.com/nsheaps/op-exec)) is a
convenience wrapper around `op run` that simplifies injecting 1Password secrets
into command execution.

## Overview

op-exec fetches all STRING and CONCEALED fields from a 1Password item, converts
field labels to environment variable names (UPPER_SNAKE_CASE), recursively
resolves any `op://` references in field values (max depth 5), and either
exports them for a command or prints `export` statements for sourcing.

## Installation

### Via mise (recommended)

```toml
# mise.toml
[tools]
"github:nsheaps/op-exec" = "latest"
```

### Via Homebrew

```bash
brew install nsheaps/tap/op-exec
```

### Via GitHub releases

```bash
curl -fsSL "https://github.com/nsheaps/op-exec/releases/download/v${VERSION}/op-exec-linux-amd64" -o op-exec
chmod +x op-exec
```

## Usage

```bash
# Run a command with all fields from a 1Password item as env vars
op-exec op://vault/item -- command [args...]

# Print export statements (for sourcing or debugging)
op-exec op://vault/item

# Source into current shell
eval "$(op-exec op://vault/item)"
```

## Prerequisites

- 1Password CLI (`op`) must be installed and authenticated
- Either signed in interactively or via `OP_SERVICE_ACCOUNT_TOKEN`

## Common Patterns

### Expose an Entire Item as Environment

```bash
# All fields from the ENVIRONMENT item become env vars
# e.g. field "API Key" → API_KEY, field "Database URL" → DATABASE_URL
op-exec op://MyVault/ENVIRONMENT -- npm start
```

### Run a Script with Secrets

```bash
op-exec op://Development/my-app-config -- ./deploy.sh
```

### Use with Docker

```bash
op-exec op://Work/docker-secrets -- docker compose up
```

### CI/CD Integration

```bash
export OP_SERVICE_ACCOUNT_TOKEN="ops_..."
op-exec op://Automation/deploy-config -- ./ci-script.sh
```

### Recursive Resolution

Field values that are themselves `op://` references are resolved automatically:

```
# Item "ENVIRONMENT" in vault "MyVault":
#   API_KEY = op://MyVault/api-credentials/key    ← resolved recursively
#   DB_HOST = prod.db.example.com                  ← used as-is
```

## Plugin Settings — Automatic Session Injection

The `1pass` plugin can automatically run op-exec at session start and write
the resolved environment variables to multiple targets.

### Configuration

```yaml
1pass:
  installOpExec: true
  opExecVersion: "latest"

  opExec:
    # 1Password items to expose as environment variables
    items:
      - "op://MyVault/ENVIRONMENT"
      - "op://MyVault/extra-secrets"

    # Where to write the resolved env vars (multiple allowed)
    # Defaults to both targets when omitted.
    targets:
      - sessionStartBashEnv # → CLAUDE_ENV_FILE (session-scoped, bash only)
      - userSettings # → ~/.claude/settings.local.json .env (persistent, all tools)

    # Note: recursive resolution of op:// references is always on (op-exec built-in)
```

### Output Targets

| Target                | Mechanism                              | Scope           | Persistence     | Non-Bash tools |
| --------------------- | -------------------------------------- | --------------- | --------------- | -------------- |
| `sessionStartBashEnv` | `CLAUDE_ENV_FILE`                      | Bash tool calls | Session only    | No             |
| `userSettings`        | `~/.claude/settings.local.json` `.env` | All tools       | Across sessions | Yes            |

**Default:** Both `sessionStartBashEnv` and `userSettings` are enabled when
`targets` is not specified, ensuring env vars are available to all tools and
also in bash sessions.

### When to Use Which Target

- **sessionStartBashEnv only**: Secrets that should not persist on disk beyond
  the session, or when you only need them in bash tool calls.
- **userSettings only**: Config that non-Bash tools (MCP servers, etc.) need,
  or values that should persist across sessions.
- **Both (default)**: Most common — ensures secrets are available everywhere
  during the session and to all tool types.

## Troubleshooting

### "op-exec: command not found"

Install via mise, Homebrew, or enable auto-install in the plugin settings.

### Secrets not resolving

Ensure `op` is authenticated:

```bash
op whoami
```

### Permission denied

Ensure the service account or user has access to the referenced vault.

### No fields exported

op-exec only exports STRING and CONCEALED field types. Other field types
(sections, OTP, etc.) are skipped. Verify the item has the expected fields:

```bash
op item get "ENVIRONMENT" --vault "MyVault" --format json | jq '.fields[] | {label, type}'
```
