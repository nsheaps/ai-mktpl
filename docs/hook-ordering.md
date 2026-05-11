# Hook Ordering in Claude Code Plugins

## Problem

Claude Code does not guarantee the execution order of `SessionStart` hooks across plugins. When one plugin depends on environment variables that another plugin would otherwise inject from its own hook, the dependent plugin's hook may run first and find the variables empty.

**Example:** The `github-app` plugin needs `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, and `GITHUB_APP_PRIVATE_KEY_PATH` to generate a token. If a secret-resolving plugin (such as `1pass`) is responsible for injecting those values via its own SessionStart hook, the `github-app` hook may fire first and see empty variables.

## Why Polling Process Env Vars Doesn't Work

Each SessionStart hook runs in its own subprocess. Env vars `export`ed inside one hook's subprocess are **never visible** to another hook's subprocess — subprocess environments are isolated by the OS.

Polling `[[ -n "${VAR:-}" ]]` inside a hook will never observe values written by another hook's subprocess.

## Recommended Pattern: Launcher Sources `.env` Before Exec

The ai-mktpl agent harness uses a launcher script (`bin/agent`) that sources the agent's `.env` / `.env.local` chain **before** exec'ing `claude`. By the time any plugin SessionStart hook fires, the required env vars are already in process env — no inter-hook coordination is necessary.

```text
bin/agent
  ├─ source $AGENT_HOME_DIR/.env          # repo-templated, sources .env.local
  │    └─ source $AGENT_HOME_DIR/.env.local # 1pass-managed secrets
  ├─ exec claude                           # all required env vars are now in process env
  │    │
  │    ├─ SessionStart hook A (e.g. github-app) — sees GITHUB_APP_ID etc.
  │    └─ SessionStart hook B — also sees the same env
```

Plugins that depend on env vars should:

1. **Fail fast** if a required var is missing — log the missing vars by name and exit 0 (informational), or fail loudly if the agent will be useless without them.
2. **Document the required env vars** in the plugin README so the launcher author knows what to provision.
3. **Not poll, not wait, not retry.** If the var isn't there at hook time, it isn't going to appear later via another hook.

### Example (from `plugins/github-app/hooks/scripts/github-token-init.sh`)

```bash
# Fail-fast: required env vars must be present.
# The launcher is responsible for populating process env. If any required var
# is missing, we abort loudly rather than silently leaving the session
# unauthenticated.
if ! require_static_env; then
  hook_log "required JWT-signing env vars missing; aborting"
  hook_respond
  exit 0
fi
```

`require_static_env` is a plugin-internal helper that checks for the documented set of required env vars and logs the missing ones by name.

## When Hook-to-Hook Coordination Is Unavoidable

If two plugins genuinely need to share state mid-session (rare), use `CLAUDE_ENV_FILE` — a shared file that Claude Code sources before each Bash tool call. Plugin A writes `export KEY=value` to it; subsequent Bash tool calls (and therefore subsequent PreToolUse / PostToolUse hooks invoked via Bash) see the value.

This is **not** a substitute for the launcher-sources-env pattern at session start — `CLAUDE_ENV_FILE` is only re-sourced between tool calls, not between concurrent SessionStart hooks. Use it for refresh-style updates (e.g. token rotation propagating a new `GH_TOKEN`), not for initial bootstrapping.

## Plugin Author Guidelines

- **Do not assume hook order.** If your plugin requires env vars from another plugin's SessionStart hook, you have a design problem — push that responsibility up to the launcher's `.env` chain instead.
- **Do not poll process env vars across hooks.** Each SessionStart hook is a separate subprocess; env vars exported by one subprocess are invisible to others.
- **Document required env vars in your plugin README.** Make the launcher's contract explicit.
- **Exit 0 with a clear log on missing config.** Informational hooks should not block the session.
- **Use `CLAUDE_ENV_FILE` only for between-tool-call propagation.** Not for session-start coordination.

## Reference

- `plugins/github-app/hooks/scripts/github-token-init.sh` — fail-fast SessionStart hook
- `plugins/github-app/specs/setup-hook-static-config-split.md` — design rationale for launcher-owns-static-config
- `plugins/github-app/README.md` — example documentation of required env vars
