# Hook Ordering and Secret Resolution

## The Problem

Claude Code runs SessionStart hooks in **separate subprocesses** with no guaranteed execution order. Environment variables exported by one hook (e.g., the 1pass plugin writing to its subprocess environment) never propagate to another hook's subprocess.

This means the github-app hook cannot rely on the 1pass plugin to have already exported `GITHUB_APP_ID` into the shared environment before github-app's hook runs.

## Solution: Self-Contained Secret Resolution

The recommended approach is to make the github-app plugin **self-contained** for secret resolution. It does this by resolving `op://` references directly using the `op` CLI — without depending on the 1pass plugin or hook execution order.

### Why This Works

The `OP_SERVICE_ACCOUNT_TOKEN` environment variable is injected by the agent launcher via `settings.local.json` **before** any hooks run. This means every SessionStart subprocess already has `op` auth available. The github-app hook can call `op read` directly.

### Configuration

Set `ref` to an `op://` item reference in `plugins.settings.yaml`:

```yaml
github-app:
  ref: "op://vault/github-app--my-repo"
```

The plugin reads each expected field from the item:
- `GITHUB_APP_ID`
- `GITHUB_APP_CLIENT_ID`
- `GITHUB_APP_CLIENT_SECRET`
- `GITHUB_APP_PRIVATE_KEY`
- `GITHUB_INSTALLATION_ID`

Individual fields can also be referenced via `secrets.*`:

```yaml
github-app:
  secrets:
    github_app_id: "op://vault/item/GITHUB_APP_ID"
    github_app_private_key: "op://vault/item/GITHUB_APP_PRIVATE_KEY"
    github_installation_id: "op://vault/item/GITHUB_INSTALLATION_ID"
```

## Fallback: CLAUDE_ENV_FILE Polling

If `op` is not available or credentials were not resolved via `op://`, the plugin falls back to polling `CLAUDE_ENV_FILE`. This covers cases where the 1pass plugin (or another mechanism) writes credentials to the shared env file asynchronously.

The fallback uses exponential backoff (1s, 2s, 4s, 4s, ...) up to a 15-second timeout. If credentials don't appear in time, the plugin exits gracefully (skipping token generation rather than hard-failing).

## Resolution Priority

1. **`ref: op://...`** — Resolve all fields directly from 1Password (primary, self-contained)
2. **`ref: env-file://...`** — Source from a local env file
3. **`secrets.*` with `op://` values** — Resolve individual fields from 1Password
4. **`secrets.*` with `${VAR}` or literals** — Read from environment or config
5. **`CLAUDE_ENV_FILE` polling** — Wait for another plugin to write credentials
6. **Environment variables** — Already present in the subprocess at startup

## Implementation

Secret resolution is implemented in `lib/resolve-secrets.sh`, which provides:

- `resolve_op_ref <ref>` — Resolve a single `op://` reference; returns 1 if op is unavailable
- `wait_for_env_file [VAR...] [--timeout N]` — Poll `CLAUDE_ENV_FILE` for vars to appear
- `_op_available` — Check if op CLI is present and `OP_SERVICE_ACCOUNT_TOKEN` is set
