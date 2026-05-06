# Spec: Setup Hook + Static/Runtime Config Split

Status: draft
Plugin: `github-app`
Target version: 0.4.0 (breaking config layout change)
Tracks: BUG-19

## Background — what's broken (BUG-19)

The pre-0.4.0 SessionStart hook sourced `${AGENT_CONFIG_DIR}/github-app-env` and
re-derived `GITHUB_APP_ID` / `GITHUB_INSTALLATION_ID` / `GITHUB_APP_PRIVATE_KEY_PATH`
from `${VAR:-}` in process env on every refresh, then persisted the result back
to disk. Any one-time cross-agent env contamination (the wrong agent's `GITHUB_APP_ID`
in the launcher's environment) made the file the wrong agent's identity
permanently — every subsequent refresh re-cemented the wrong values.

## Goals

1. **Make the JWT signing inputs un-stompable** at runtime. Once written by Setup,
   they are not re-read from process env or re-written by any subsequent hook.
2. **Cleanly separate immutable inputs from mutable runtime state** in distinct
   files, owned by distinct hooks.
3. **Refuse to run with an unknown agent identity.** If `AGENT_NAME` is unset or
   `_UNKNOWN`, hard-fail rather than write into a shared path.
4. **Adopt an XDG-style per-app subdirectory** (`${AGENT_CONFIG_DIR}/github-app/`).
5. **Self-migrate** existing agents away from the pre-0.4.0 flat env file.

## Design

### Lifecycle

| Phase           | Hook                   | Trigger              | Writes                              | Reads                                  |
| --------------- | ---------------------- | -------------------- | ----------------------------------- | -------------------------------------- |
| Install/upgrade | `Setup{matcher: init}` | `claude --init-only` | `static.env`, initial token + meta  | process env (set by launcher + 1pass)  |
| Session start   | `SessionStart`         | every session        | `runtime.env`, `git-identity.env`   | `static.env`, token + meta             |
| Pre-tool-use    | `PreToolUse`           | every Bash tool call | `runtime.env` (token only)          | `static.env`, token + meta             |

The Setup hook is the **only** writer of static config. SessionStart and
PreToolUse exclusively read it.

### Where the Setup hook gets its inputs

The launcher (`bin/agent`) sources the agent's `.env.local` (populated by the
1pass plugin from the agent's `ENVIRONMENT` 1Password item) before exec'ing
claude. By the time install.sh runs, these are present in process env:

- `GITHUB_APP_ID`
- `GITHUB_INSTALLATION_ID`
- `GITHUB_APP_PRIVATE_KEY` (inline content) **or** `GITHUB_APP_PRIVATE_KEY_PATH`
- `GITHUB_APP_CLIENT_ID` (optional)
- `GITHUB_APP_CLIENT_SECRET` (optional)

`AGENT_NAME` and `AGENT_HOME_DIR` are set by `bin/agent` from `agent.yaml` (NOT
from any 1pass secret). The Setup hook uses them — and only them — to derive
isolation paths:

- `GH_CONFIG_DIR=${AGENT_HOME_DIR}/.config/gh`
- `GIT_CONFIG_GLOBAL=${AGENT_HOME_DIR}/.config/git/config`

This mirrors the standard XDG-style `${HOME}/.config/<appname>/` layout for
each app, scoped to the agent's home directory.

If any required env var is unset, install.sh fails loudly with a one-line
message naming the missing var. There's no fallback, retry, or interpolation —
if the secret is misconfigured the operator will know immediately.

### File layout

```
${AGENT_HOME_DIR}/.config/
├── github-app/
│   ├── static.env              # immutable inputs — written by Setup only
│   ├── runtime.env             # mutable token+identity — rewritten on each refresh
│   ├── git-identity.env        # stable git identity vars
│   ├── token                   # current installation token (chmod 600)
│   ├── token.meta              # JSON metadata (expiry, app_slug, bot_id, ...)
│   ├── private-key.pem         # PEM (only when key was provided as content)
│   └── last-check              # PreToolUse debounce timestamp
├── gh/                         # GH_CONFIG_DIR (isolation)
└── git/config                  # GIT_CONFIG_GLOBAL (isolation)
```

The pre-0.4.0 flat file at `${AGENT_CONFIG_DIR}/github-app-env` is removed by
`migrate_legacy_layout`, which is kept one cycle for auto-cleanup.

### static.env contents

```sh
export GITHUB_APP_ID="..."
export GITHUB_INSTALLATION_ID="..."
export GITHUB_APP_PRIVATE_KEY_PATH="..."     # absolute path
export GITHUB_APP_CLIENT_ID="..."            # optional
export GITHUB_APP_CLIENT_SECRET="..."        # optional
export GH_CONFIG_DIR="..."                   # AGENT_HOME_DIR-derived
export GIT_CONFIG_GLOBAL="..."               # AGENT_HOME_DIR-derived
export GITHUB_APP_STATIC_REF="env"
export GITHUB_APP_STATIC_WRITTEN_AT="..."
```

Permissions: 600. Sourced directly by SessionStart and PreToolUse (NOT through
`CLAUDE_ENV_FILE`).

### runtime.env contents

Written by SessionStart on every session and PreToolUse on every refresh:

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

Critically: **no `GITHUB_APP_ID`, `GITHUB_INSTALLATION_ID`, or `GITHUB_APP_PRIVATE_KEY_PATH`**.

This file is sourced via `CLAUDE_ENV_FILE` so each Bash tool call sees the fresh
token.

### Path derivation hardening

`lib/agent-paths.sh` hard-fails when `AGENT_NAME` is unset or `_UNKNOWN`,
unless `GITHUB_APP_ALLOW_UNKNOWN_AGENT=1` is explicitly set (for tooling that
intentionally runs without an agent identity).

### Setup hook (`hooks/scripts/install.sh`)

1. Source shared libs (plugin-config-read, hook-logging, agent-paths, env-file).
2. Hard-fail if `AGENT_NAME` / `AGENT_HOME_DIR` unset.
3. Hard-fail if `GITHUB_APP_ID` / `GITHUB_INSTALLATION_ID` unset.
4. Resolve PEM: write content to `${GITHUB_APP_CONFIG_DIR}/private-key.pem` if
   given inline; otherwise use the configured path.
5. Derive `GH_CONFIG_DIR` / `GIT_CONFIG_GLOBAL` from `AGENT_HOME_DIR`.
6. `write_static_env_file` — atomic write of all of the above.
7. `bin/generate-token.sh` — mint initial installation token.
8. `migrate_legacy_layout` — clean up pre-0.4.0 flat file.

Total: ~30 lines of logic. No retries, no `op://`/`env-file://` resolvers, no
`secrets.*` interpolation rejection — those concerns moved upstream to the
1pass plugin (which already owns secret resolution) and `bin/agent` (which
sources the resulting `.env.local` and unsets contaminating vars before exec).

### SessionStart hook (`hooks/scripts/github-token-init.sh`)

1. Source `static.env` (the **only** source of `GITHUB_APP_ID` etc. for this
   process — and now also `GH_CONFIG_DIR` / `GIT_CONFIG_GLOBAL`).
2. If `static.env` is missing, run install.sh inline as a fallback for in-flight
   sessions migrating from 0.3.x.
3. Refresh-or-regenerate the token. Write `runtime.env` and `git-identity.env`.
4. Append source lines to `CLAUDE_ENV_FILE`.

### PreToolUse hook (`hooks/scripts/github-token-check.sh`)

1. Source `static.env`.
2. `bin/token-check.sh --sync --quiet` if expiring; rewrites `runtime.env`
   (token only).
3. Never touches `static.env`.

## Future work (intentionally out of scope)

One follow-up remains, tracked in [ai-mktpl#491](https://github.com/nsheaps/ai-mktpl/issues/491):

- **mcpmon-style watcher** for `.env.local` change → restart MCP servers,
  *combined with* moving the 1pass secret fetch into a Setup hook. These two
  pieces share the same blocker — MCP server env propagation — and should
  ship together. Once the watcher exists, the plugin can stop relying on
  `bin/agent` to source `.env.local`.

The TS rewrite of plugin bash scripts is tracked separately in
[ai-mktpl#312](https://github.com/nsheaps/ai-mktpl/issues/312); it does not
gate on this spec.

The `CLAUDE_ENV_FILE` source-of-source pattern is implemented inline in this
PR — see "SessionStart hook" steps 4 above.

## Test plan

- `lib/agent-paths.sh` exits non-zero when `AGENT_NAME` is unset or `_UNKNOWN`.
- `lib/env-file.sh::write_runtime_env_file` does NOT emit `GITHUB_APP_ID` or
  `GITHUB_APP_PRIVATE_KEY_PATH`.
- `write_static_env_file` writes the expected fields including `GH_CONFIG_DIR` /
  `GIT_CONFIG_GLOBAL`, chmods 600.
- Setup with required env vars set writes static.env and mints a token.
- Setup with required env vars *unset* fails loudly (and does not write a
  partial static.env).
- Migration: pre-0.4.0 layout is removed after install.sh runs.

## Migration risks

| Risk                                       | Mitigation                                                       |
| ------------------------------------------ | ---------------------------------------------------------------- |
| Existing 0.3.5 sessions running mid-flight | SessionStart fallback calls install.sh if static.env missing     |
| `tokenFile` config override                | Honored unchanged                                                |
| User has a manually placed PEM             | Setup canonicalizes any configured path; doesn't move user PEMs  |

## Version

Plugin version bump: **0.3.5 → 0.4.0**.

## References

- BUG-19 — empirical reproduction (2026-05-06).
- BUG-7 — git identity resolution (existing fail-loud behavior preserved).
- shared-lib `Setup{matcher: init}` precedent.
- PR #487 review (handler feedback) — drove the simplification away from
  in-plugin secret resolution toward trusting upstream 1pass + bin/agent.
