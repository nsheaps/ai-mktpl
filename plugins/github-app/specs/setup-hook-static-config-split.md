# Spec: Plugin Scoped to Runtime Token Refresh

Status: draft
Plugin: `github-app`
Target version: 0.4.0 (breaking config layout change)
Tracks: BUG-19, PR #487 handler feedback (2026-05-11)

## Background — what's broken (BUG-19) and what changed

The pre-0.4.0 SessionStart hook sourced `${XDG_CONFIG_HOME}/github-app-env` and
re-derived `GITHUB_APP_ID` / `GITHUB_APP_INSTALLATION_ID` / `GITHUB_APP_PRIVATE_KEY_PATH`
from `${VAR:-}` in process env on every refresh, then persisted the result back
to disk. Any one-time cross-agent env contamination made the file the wrong
agent's identity permanently — every subsequent refresh re-cemented the wrong
values.

An earlier iteration of this PR (#487) addressed BUG-19 by introducing a
`static.env` written exclusively by a `Setup{init}` hook. Handler feedback
(2026-05-11) rejected that approach in favor of moving static-credential
ownership upstream entirely:

- `$AGENT_HOME_DIR/.env.local` is 1pass-managed (handled by the 1pass plugin).
- `$AGENT_HOME_DIR/.env` is repo-templated and sources `.env.local`.
- The launcher (`bin/agent`) sources `$AGENT_HOME_DIR/.env` before exec'ing
  claude.

So `GITHUB_APP_ID` / `GITHUB_APP_INSTALLATION_ID` / `GITHUB_APP_PRIVATE_KEY_PATH`
are already in process env by the time any github-app hook fires. This plugin
no longer manages or persists static credentials.

## Goals

1. **Plugin runs independently of any secret manager.** No 1pass coupling, no
   `op://` resolution, no `env-file://` parsing — the plugin trusts the
   launcher's env chain.
2. **Fail fast** when required env vars are missing. No fallback, no bypass.
3. **Refuse to run with an unknown agent identity.** If `AGENT_NAME` /
   `XDG_CONFIG_HOME` is unset, hard-fail rather than write into a shared path.
4. **Adopt the XDG Base Directory spec** — derive paths from
   `${XDG_CONFIG_HOME}/github-app/` (the launcher sets XDG_CONFIG_HOME to the
   agent's config root).
5. **Self-migrate** existing agents away from pre-0.4.0 layouts and from the
   abandoned `static.env` layout.

## Design

### Lifecycle

| Phase         | Hook           | Trigger              | Writes                                   | Reads                   |
| ------------- | -------------- | -------------------- | ---------------------------------------- | ----------------------- |
| Session start | `SessionStart` | every session        | `runtime.env`, `git-identity.env`, token | process env, token meta |
| Pre-tool-use  | `PreToolUse`   | every Bash tool call | `runtime.env` (token only, on refresh)   | process env, token meta |

There is **no Setup hook**. Static credentials live in process env (sourced
by the launcher); the plugin reads them at every hook invocation.

### Required process env

The launcher MUST set these before `claude` exec:

- `AGENT_NAME` — propagated to all hooks for path derivation.
- `AGENT_HOME_DIR` — used to derive `GH_CONFIG_DIR` / `GIT_CONFIG_GLOBAL`.
- `XDG_CONFIG_HOME` — set to `$AGENT_HOME_DIR/.config` per XDG spec.
- `GITHUB_APP_ID`
- `GITHUB_APP_INSTALLATION_ID`
- `GITHUB_APP_PRIVATE_KEY_PATH` — absolute path to PEM file (a path, not
  inline content — the launcher's .env chain writes inline secrets to disk
  upstream).

If any required var is missing, `require_static_env` (in `lib/env-file.sh`)
fails loudly with a one-line message naming each missing var. There's no
fallback or retry.

### File layout

```
${AGENT_HOME_DIR}/.config/
├── github-app/
│   ├── runtime.env             # mutable token+identity — rewritten on each refresh
│   ├── git-identity.env        # stable git identity vars
│   ├── token                   # current installation token (chmod 600)
│   ├── token.meta              # JSON metadata (expiry, app_slug, bot_id, ...)
│   └── last-check              # PreToolUse debounce timestamp
├── gh/                         # GH_CONFIG_DIR (isolation)
└── git/config                  # GIT_CONFIG_GLOBAL (isolation)
```

Pre-0.4.0 `${XDG_CONFIG_HOME}/github-app-env` and any leftover
`${GITHUB_APP_CONFIG_DIR}/static.env` from the abandoned static-split iteration
are removed by `migrate_legacy_layout` on every session start.

### runtime.env contents

Written by SessionStart on every session and by `bin/token-check.sh` on every
refresh:

```sh
export GH_TOKEN="..."
export GITHUB_TOKEN="..."
export GITHUB_TOKEN_FILE="..."
export GITHUB_APP_ENV_FILE="..."
export GH_CONFIG_DIR="..."
export GIT_CONFIG_GLOBAL="..."
export GIT_AUTHOR_NAME="..."
export GIT_AUTHOR_EMAIL="..."
# + GIT_COMMITTER_*
```

Critically: **no `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, or
`GITHUB_APP_PRIVATE_KEY_PATH`** — those come from the launcher's env chain on
every invocation, never from a plugin-owned file.

This file is sourced via `CLAUDE_ENV_FILE` so each Bash tool call sees the
fresh token.

### Path derivation hardening

`lib/agent-paths.sh` hard-fails when `AGENT_NAME` is unset or `_UNKNOWN`, or
when `XDG_CONFIG_HOME` is unset. There is no bypass — the previous
`GITHUB_APP_ALLOW_UNKNOWN_AGENT` escape hatch has been removed (PR #487
handler feedback 2026-05-11).

### SessionStart hook (`hooks/scripts/github-token-init.sh`)

1. Validate required env vars via `require_static_env` (fail-fast on missing).
2. Derive `GH_CONFIG_DIR` / `GIT_CONFIG_GLOBAL` from `AGENT_HOME_DIR`.
3. Run `migrate_legacy_layout` (idempotent — cleans pre-0.4.0 flat file and
   any leftover `static.env`).
4. Refresh-or-regenerate the token.
5. Resolve bot identity from token meta; write `runtime.env` + `git-identity.env`.
6. Append source lines to `CLAUDE_ENV_FILE`.

### PreToolUse hook (`hooks/scripts/github-token-check.sh`)

1. Defer silently via `require_static_env 2>/dev/null` when env isn't set up
   (so the plugin doesn't spam errors when not configured for this agent).
2. `bin/token-check.sh --sync --quiet` if expiring; rewrites `runtime.env`
   (token only).

## Future work (intentionally out of scope)

Tracked in [ai-mktpl#491](https://github.com/nsheaps/ai-mktpl/issues/491):

- **mcpmon-style watcher** for `.env.local` change → restart MCP servers.
  This lets the plugin remain decoupled from the secret-resolution path
  while still picking up rotations.

The TS rewrite of plugin bash scripts is tracked separately in
[ai-mktpl#312](https://github.com/nsheaps/ai-mktpl/issues/312); it does not
gate on this spec.

## Test plan

- `lib/agent-paths.sh` exits non-zero when `AGENT_NAME` is unset or `_UNKNOWN`.
- `lib/env-file.sh::write_runtime_env_file` does NOT emit `GITHUB_APP_ID` or
  `GITHUB_APP_PRIVATE_KEY_PATH`.
- `require_static_env` fails loudly when JWT-signing inputs are missing and
  succeeds when present.
- `tests/contamination-resistance.sh` covers all three cases above.
- Migration: pre-0.4.0 layout and any leftover `static.env` are removed on
  session start.

## Migration risks

| Risk                                           | Mitigation                                                   |
| ---------------------------------------------- | ------------------------------------------------------------ |
| Existing pre-0.4.0 sessions running mid-flight | SessionStart regenerates token from process env on first run |
| Existing `static.env` from intermediate PR     | `migrate_legacy_layout` deletes it on session start          |
| `tokenFile` config override                    | Honored unchanged                                            |
| Launcher missing required env                  | `require_static_env` fails loudly with named missing vars    |

## Version

Plugin version bump: **0.3.5 → 0.4.0**.

## References

- BUG-19 — empirical reproduction (2026-05-06).
- BUG-7 — git identity resolution (existing fail-loud behavior preserved).
- PR #487 review (handler feedback, 2026-05-11) — drove the simplification
  away from any plugin-owned static config toward trusting the launcher's
  .env chain. Concretely:
  - removed `Setup{init}` hook and `static.env` entirely
  - removed `GITHUB_APP_ALLOW_UNKNOWN_AGENT` bypass
  - added `require_static_env` fail-fast guard
