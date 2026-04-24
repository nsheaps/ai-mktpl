# Hook Ordering in Claude Code Plugins

## Problem

Claude Code does not guarantee the execution order of `SessionStart` hooks across plugins. When one plugin depends on environment variables injected by another plugin's hook, there is a race condition: the dependent plugin may run first and find the variables empty.

**Example:** The `github-app` plugin needs `GITHUB_APP_ID`, `GITHUB_INSTALLATION_ID`, and `GITHUB_APP_PRIVATE_KEY_PATH` to generate a token. If the `1pass` plugin is responsible for injecting those values but runs after `github-app`, the `github-app` hook sees empty variables and silently skips token generation.

## Pattern: `wait-for-env` with Exponential Backoff

The `github-app` plugin provides a reusable helper at `lib/wait-for-env.sh` that polls for environment variables with exponential backoff.

### Usage

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/wait-for-env.sh"

# Wait up to 15 seconds for credentials (default timeout)
if wait_for_env GITHUB_APP_ID GITHUB_INSTALLATION_ID --timeout 15; then
  echo "credentials available"
else
  echo "timed out — plugin not configured"
  exit 0
fi
```

### How It Works

- Polls every 1 second, doubling the interval up to a maximum of 4 seconds
- Returns `0` when all specified variables are set and non-empty
- Returns `1` on timeout
- Guard-loaded (safe to `source` multiple times via `_WAIT_FOR_ENV_LOADED`)

### Recommended Timeouts

| Hook type    | Timeout | Rationale                                    |
| ------------ | ------- | -------------------------------------------- |
| SessionStart | 15s     | Startup allows more wait time                |
| PreToolUse   | 5s      | Per-tool hooks have a tighter latency budget |

## Where to Apply This Pattern

Apply `wait_for_env` in a plugin's `SessionStart` hook **before** the credentials check that exits early. The wait should only trigger if the variables are currently unset — if they are already present (e.g., from a user's shell environment), skip the wait entirely.

```bash
# Only wait if credentials aren't already in the environment
if [[ -z "${REQUIRED_VAR:-}" ]]; then
  source "${CLAUDE_PLUGIN_ROOT}/lib/wait-for-env.sh"
  if wait_for_env REQUIRED_VAR --timeout 15; then
    log "credentials became available after waiting for another plugin"
  else
    log "timeout — plugin not configured, skipping"
    exit 0
  fi
fi
```

## Example: `github-app` + `1pass`

The `1pass` plugin can be configured to expose GitHub App secrets as environment variables. When both plugins are enabled:

1. Claude Code starts both `SessionStart` hooks concurrently (order unspecified)
2. If `github-app` runs first, it finds empty env vars and enters the wait loop
3. When `1pass` finishes injecting vars, `github-app`'s wait returns successfully
4. Token generation proceeds normally

If `1pass` is not configured or fails, the wait times out and `github-app` skips gracefully with a log message.

## Plugin Author Guidelines

- **Do not assume hook order.** Any plugin that depends on env vars from another plugin should use `wait_for_env`.
- **Keep the wait scoped.** Only wait for the specific variables you need, not for a general "ready" signal.
- **Exit 0 on timeout.** Informational hooks should never block the session. Log a clear message and exit cleanly.
- **Use shorter timeouts in PreToolUse.** PreToolUse hooks run before every tool call; excessive waiting degrades the user experience.
- **Document your dependencies.** If your plugin requires another plugin to set specific env vars, document that in your `plugin.json` description or README.

## Reference

- `plugins/github-app/lib/wait-for-env.sh` — The reusable helper
- `plugins/github-app/hooks/scripts/github-token-init.sh` — Usage in a SessionStart hook
- `plugins/github-app/bin/token-check.sh` — Usage in a utility script (shorter timeout)
