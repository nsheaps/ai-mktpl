# Hook Ordering in Claude Code Plugins

## Problem

Claude Code does not guarantee the execution order of `SessionStart` hooks across plugins. When one plugin depends on environment variables injected by another plugin's hook, there is a race condition: the dependent plugin may run first and find the variables empty.

**Example:** The `github-app` plugin needs `GITHUB_APP_ID`, `GITHUB_INSTALLATION_ID`, and `GITHUB_APP_PRIVATE_KEY_PATH` to generate a token. If the `1pass` plugin is responsible for injecting those values but runs after `github-app`, the `github-app` hook sees empty variables and silently skips token generation.

## Why Polling Process Env Vars Doesn't Work

Each SessionStart hook runs in its own subprocess. Env vars `export`ed inside one hook's subprocess are **never visible** to another hook's subprocess — subprocess environments are isolated by the OS.

Polling `[[ -n "${VAR:-}" ]]` inside a hook will never observe values written by another hook's subprocess.

## Pattern: `wait_for_env_file` via `CLAUDE_ENV_FILE`

The correct mechanism is `CLAUDE_ENV_FILE` — a shared file that Claude Code sources before each Bash tool call. Plugins that need to share env vars write `export KEY=value` lines to this file. Other plugins can read (and source) this file to pick up those values.

The `github-app` plugin provides a reusable helper at `lib/wait-for-env.sh` that polls `CLAUDE_ENV_FILE` for required variables with exponential backoff, then sources the file to make them available in the current process.

### Usage

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/wait-for-env.sh"

# Wait up to 15 seconds for credentials to appear in CLAUDE_ENV_FILE
if wait_for_env_file GITHUB_APP_ID GITHUB_INSTALLATION_ID --timeout 15; then
  echo "credentials available"
else
  echo "timed out — plugin not configured"
  exit 0
fi
```

### How It Works

- Checks `CLAUDE_ENV_FILE` for `export VAR=value` lines matching each required variable
- When all are found, sources the file to make vars available in the current process
- Polls every 1 second, doubling the interval up to a maximum of 4 seconds
- Returns `0` when all specified variables are found and sourced
- Returns `1` if `CLAUDE_ENV_FILE` is not set or the timeout expires
- Guard-loaded (safe to `source` multiple times via `_WAIT_FOR_ENV_LOADED`)

### Recommended Timeouts

| Hook type    | Timeout | Rationale                                    |
| ------------ | ------- | -------------------------------------------- |
| SessionStart | 15s     | Startup allows more wait time                |
| PreToolUse   | 5s      | Per-tool hooks have a tighter latency budget |

## Where to Apply This Pattern

Apply `wait_for_env_file` in a plugin's `SessionStart` hook **before** the credentials check that exits early. The wait should only trigger if the variables are currently unset — if they are already present (e.g., from a user's shell environment), skip the wait entirely.

```bash
# Only wait if credentials aren't already in the environment
if [[ -z "${REQUIRED_VAR:-}" ]]; then
  source "${CLAUDE_PLUGIN_ROOT}/lib/wait-for-env.sh"
  if wait_for_env_file REQUIRED_VAR --timeout 15; then
    log "credentials became available after waiting for another plugin"
  else
    log "timeout — plugin not configured, skipping"
    exit 0
  fi
fi
```

## Example: `github-app` + `1pass`

The `1pass` plugin writes GitHub App secrets as `export KEY=value` lines to `CLAUDE_ENV_FILE`. When both plugins are enabled:

1. Claude Code starts both `SessionStart` hooks concurrently (order unspecified)
2. If `github-app` runs first, it finds empty env vars and enters the `wait_for_env_file` loop
3. When `1pass` finishes writing to `CLAUDE_ENV_FILE`, `github-app`'s wait detects the lines, sources the file, and returns successfully
4. Token generation proceeds normally

If `1pass` is not configured or fails, the wait times out and `github-app` skips gracefully with a log message.

## Plugin Author Guidelines

- **Do not assume hook order.** Any plugin that depends on env vars from another plugin should use `wait_for_env_file`.
- **Do not poll process env vars.** Each SessionStart hook is a separate subprocess; env vars exported by one subprocess are invisible to others.
- **Use `CLAUDE_ENV_FILE` as the shared bus.** Write `export KEY=value` lines there; read them with `wait_for_env_file`.
- **Keep the wait scoped.** Only wait for the specific variables you need, not for a general "ready" signal.
- **Exit 0 on timeout.** Informational hooks should never block the session. Log a clear message and exit cleanly.
- **Use shorter timeouts in PreToolUse.** PreToolUse hooks run before every tool call; excessive waiting degrades the user experience.
- **Document your dependencies.** If your plugin requires another plugin to set specific env vars, document that in your `plugin.json` description or README.

## Reference

- `plugins/github-app/lib/wait-for-env.sh` — The reusable helper
- `plugins/github-app/hooks/scripts/github-token-init.sh` — Usage in a SessionStart hook
- `plugins/github-app/bin/token-check.sh` — Usage in a utility script (shorter timeout)
