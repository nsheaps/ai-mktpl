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
      - envLocal            # → $AGENT_HOME_DIR/.env.local (persistent, idempotent)
      - userSettings # → ~/.claude/settings.local.json .env (persistent, all tools)


  # envLocal target configuration (only consulted when "envLocal" is in targets above)
  envLocal:
    # path: '$AGENT_HOME_DIR/.env.local'   # default
    # sourceChain: '$AGENT_HOME_DIR/.env'  # default; pass "self" to chain envLocal directly,
                                           # or "none" to skip adding any source line.

    # Note: recursive resolution of op:// references is always on (op-exec built-in)
```

### Output Targets

| Target                | Mechanism                              | Scope           | Persistence     | Non-Bash tools |
| --------------------- | -------------------------------------- | --------------- | --------------- | -------------- |
| `sessionStartBashEnv` | `CLAUDE_ENV_FILE`                      | Bash tool calls | Session only    | No             |
| `envLocal`            | `$AGENT_HOME_DIR/.env.local` (shell-sourceable `export K=v` lines) | All tools sourcing the file (e.g. direnv) | Across sessions (idempotent replace-or-append) | Yes — when sourced by the consumer |
| `userSettings`        | `~/.claude/settings.local.json` `.env` | All tools       | Across sessions | Yes            |

**Default:** Both `sessionStartBashEnv` and `userSettings` are enabled when
`targets` is not specified, ensuring env vars are available to all tools and
also in bash sessions. `envLocal` is opt-in.

### envLocal target details

- Writes shell-sourceable `export KEY=value` lines to `envLocal.path`
  (default `$AGENT_HOME_DIR/.env.local`, fallback `$CLAUDE_PROJECT_DIR/.env.local`).
- Uses idempotent **replace-or-append** semantics (via shared-lib's
  `env_file_upsert_export`). The file is NOT truncated on session start, so
  vars from other sources (manual edits, other plugins) survive.
- On first write of the session, also adds `source <envLocal.sourceChain>` to
  `CLAUDE_ENV_FILE`. Default `sourceChain` is `$AGENT_HOME_DIR/.env` (allowing a
  repo-templated `.env` to `source .env.local` so direnv and other consumers
  pick up the vars). Pass `sourceChain: self` to source the envLocal file
  directly from `CLAUDE_ENV_FILE`, or `sourceChain: none` to skip the source
  line entirely.
- The agent repo is responsible for `.gitignore`'ing `.env.local` (and `.env`
  if applicable) and for setting up the consumer-side `source` of the file.

### When to Use Which Target

- **sessionStartBashEnv only**: Secrets that should not persist on disk beyond
  the session, or when you only need them in bash tool calls.
- **envLocal**: When non-Claude-Code processes need the vars (e.g. direnv,
  scripts run from a shell). Combines well with a repo-templated `.env` that
  sources `.env.local` for the consumer side.
- **userSettings only**: Config that non-Bash tools (MCP servers, etc.) need,
  or values that should persist across sessions.

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
