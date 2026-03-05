---
name: op-exec
description: >
  Use this skill when the user asks about op-exec, running commands with
  1Password secrets injected, wrapping processes with secret injection,
  or automating secret-aware command execution. op-exec is a wrapper around
  the 1Password CLI that simplifies running commands with secrets from
  1Password vaults.
---

# op-exec - 1Password Secret Injection Wrapper

`op-exec` (from [nsheaps/op-exec](https://github.com/nsheaps/op-exec)) is a
convenience wrapper around `op run` that simplifies injecting 1Password secrets
into command execution.

## Overview

op-exec streamlines the pattern of running commands with secrets from 1Password
by providing a simpler interface than `op run` for common use cases.

## Installation

### Via mise (recommended)

```toml
# mise.toml
[tools]
# Once available via GitHub releases:
"ubi:nsheaps/op-exec" = "latest"
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
# Run a command with secrets from 1Password
op-exec <command> [args...]
```

op-exec reads environment variables containing `op://` secret references and
resolves them before executing the wrapped command.

## Prerequisites

- 1Password CLI (`op`) must be installed and authenticated
- Either signed in interactively or via `OP_SERVICE_ACCOUNT_TOKEN`

## Common Patterns

### Run a Script with Secrets

```bash
# Environment variables with op:// references get resolved
export DATABASE_URL="op://Private/Database/connection_string"
op-exec ./deploy.sh
```

### Use with Docker

```bash
export DB_PASSWORD="op://Private/Database/password"
op-exec docker compose up
```

### CI/CD Integration

```bash
export OP_SERVICE_ACCOUNT_TOKEN="ops_..."
export API_KEY="op://Automation/Deploy Key/credential"
op-exec ./ci-script.sh
```

## Plugin Settings

This tool is installed by the `1password-tool` plugin when `install_op_exec: true`:

```yaml
1password-tool:
  install_op_exec: true
  op_exec_version: "latest"
```

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
