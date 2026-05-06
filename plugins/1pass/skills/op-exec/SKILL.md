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
    # Defaults to sessionStartBashEnv + projectEnvLocal when omitted.
    targets:
      - sessionStartBashEnv # → CLAUDE_ENV_FILE (session-scoped, bash only)
      - projectEnvLocal # → $CLAUDE_PROJECT_DIR/.env.local (per-repo, gitignored, direnv-consumable)
      # - userSettings      # → ~/.claude/settings.local.json .env (DEPRECATED for opExec)

    # Note: recursive resolution of op:// references is always on (op-exec built-in)
```

### Output Targets

| Target                | Mechanism                              | Scope                  | Persistence            | Non-Bash tools              |
| --------------------- | -------------------------------------- | ---------------------- | ---------------------- | --------------------------- |
| `sessionStartBashEnv` | `CLAUDE_ENV_FILE`                      | Bash tool calls        | Session only           | No                          |
| `projectEnvLocal`     | `$CLAUDE_PROJECT_DIR/.env.local`       | Per-repo, gitignored   | Truncated each session | Via direnv                  |
| `userSettings`        | `~/.claude/settings.local.json` `.env` | User-global, all tools | Across sessions        | Yes (DEPRECATED for opExec) |

**Default:** `sessionStartBashEnv` and `projectEnvLocal` are enabled when
`targets` is not specified, ensuring env vars are available in Bash tool calls
and also picked up by direnv (so non-Claude-Code processes invoked from the
agent repo see them too).

`projectEnvLocal` writes to `$CLAUDE_PROJECT_DIR/.env.local` in shell-sourceable
format (`export KEY=$(printf '%q' value)` lines, same as `CLAUDE_ENV_FILE`). The
file is **truncated at the start of every session** so removed secrets do not
linger. The agent repo MUST list `.env.local` in `.gitignore` and source it via
direnv (`dotenv_if_exists .env.local` in `.envrc`).

`userSettings` is **deprecated for opExec usage**. It still works for back-compat
when explicitly listed, but new configurations should use `projectEnvLocal`. Its
JSON-merge into `~/.claude/settings.local.json` is user-global rather than
per-repo, which is rarely the intended scope for resolved 1Password env.

### When to Use Which Target

- **sessionStartBashEnv only**: Secrets that should not persist on disk beyond
  the session, or when you only need them in bash tool calls.
- **projectEnvLocal**: Per-repo env that direnv (and other tooling) can pick up
  automatically when entering the directory. Default for new configurations.
- **userSettings**: DEPRECATED for opExec. Use only when you need the resolved
  vars to persist user-globally across all repos for non-Bash tools.
- **Both defaults (sessionStartBashEnv + projectEnvLocal)**: Most common — env
  is available in Claude Code Bash and to any process direnv loads.

## ENVIRONMENT Aggregator Pattern

The `ENVIRONMENT` item in 1Password (e.g., `op://AI-Jack/ENVIRONMENT`) serves as the
canonical aggregator for all environment variables. Instead of adding separate items to
`opExec.items`, add new secrets as fields to the ENVIRONMENT item:

1. In 1Password, add a new field to the ENVIRONMENT item with the desired env var name
   as the label (e.g., `DISCORD_BOT_TOKEN`)
2. Set the field value to an `op://` reference pointing to the actual secret
   (e.g., `op://AI-Jack/discord--jack_oat_bot/token`)
3. op-exec resolves references recursively, so the field value will be the actual secret
   at runtime
4. The field label becomes the exported env var name (converted to UPPER_SNAKE_CASE)

This pattern means you only need one item in `opExec.items` (the ENVIRONMENT item) to
manage all secrets. Adding separate items should be avoided unless the secret doesn't
fit the aggregator pattern.

### Example

```
ENVIRONMENT item fields:
- TELEGRAM_BOT_TOKEN = op://AI-Jack/telegram-bot/token
- DISCORD_BOT_TOKEN = op://AI-Jack/discord--jack_oat_bot/token
- BRAINTRUST_API_KEY = op://AI-Jack/braintrust/api-key
```

### Plugin Config with Aggregator

When using the aggregator pattern, the plugin config is minimal — just one item:

```yaml
1pass:
  opExec:
    items:
      - "op://AI-Jack/ENVIRONMENT"
```

All env vars are managed by adding/removing fields on that single 1Password item,
rather than editing plugin configuration.

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
