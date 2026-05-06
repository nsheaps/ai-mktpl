# Spec: Setup Hook + Static/Runtime Config Split

Status: draft
Plugin: `github-app`
Target version: 0.4.0 (breaking config layout change)
Tracks: BUG-19

## Background — what's broken (BUG-19)

The github-app plugin's SessionStart hook (`hooks/scripts/github-token-init.sh`)
sources `${AGENT_CONFIG_DIR}/github-app-env` to populate process env. That same
file ALSO contains the immutable inputs to JWT signing —
`GITHUB_APP_ID`, `GITHUB_INSTALLATION_ID`, `GITHUB_APP_PRIVATE_KEY_PATH` — plus
`GIT_AUTHOR_*`/`GIT_COMMITTER_*`. The file gets rewritten on every refresh by
`lib/env-file.sh:write_runtime_env_file()`, which reads those values from
`${VAR:-}` in process env — meaning whatever is in env at refresh time gets
persisted back to the file.

Result: any one-time contamination (e.g. cross-agent env bleed at agent launch)
makes the file the wrong agent's identity permanently, and every refresh
re-cements the wrong `GITHUB_APP_ID`. The JWT is then signed for the wrong app
and exchanged at the wrong installation, producing the wrong bot's token.
`token.meta` records `app_slug` for the wrong bot even on a fresh refresh.

This was confirmed empirically on Jack's machine (2026-05-06):
`op-exec op://Agent-Jack/github--app--jack` returned Jack's correct App ID
(2638903, installation 118953149), but the stale env file overrode them at
SessionStart, and the next refresh persisted the wrong values back. Nate also
noted earlier that "part of the issue was a misconfig on Alex where he was
writing to Jack's config dir by accident" — i.e. the path-derivation logic must
prevent one agent from clobbering another's files.

## Goals

1. **Make the JWT signing inputs un-stompable** at runtime. Once written by Setup
   from the vault source-of-truth, they must not be re-read from process env or
   re-written by any subsequent hook.
2. **Cleanly separate immutable inputs from mutable runtime state** in distinct
   files, owned by distinct hooks (Setup writes static; SessionStart/PreToolUse
   write runtime).
3. **Refuse to run with an unknown agent identity.** If `AGENT_NAME` is unset or
   `_UNKNOWN`, the plugin must hard-fail rather than write into a shared path.
4. **Adopt an XDG-style per-app subdirectory** (`${AGENT_CONFIG_DIR}/github-app/`)
   so plugin files are namespaced and discoverable, mirroring the convention used
   by every app under `~/.config/`.
5. **Self-migrate** existing agents away from the old contaminated file with no
   manual intervention.

## Non-goals

- Changing the secret resolution surface (`ref:` op://, `ref:` env-file://,
  `secrets.*`, legacy flat settings) — all continue to work.
- Changing the token-refresh schedule, debounce/throttle, or cooldown logic.
- Changing the `gh` credential helper, the gitconfig isolation pattern, or the
  bot-identity resolution against `/app` and `/users/<slug>[bot]`.

## Design

### Lifecycle ownership

| Phase           | Hook event             | Trigger              | Writes                                            | Reads                                     |
| --------------- | ---------------------- | -------------------- | ------------------------------------------------- | ----------------------------------------- |
| Install/upgrade | `Setup{matcher: init}` | `claude --init-only` | static.env, private-key.pem, initial token + meta | plugin config (`ref:` op://, `secrets.*`) |
| Session start   | `SessionStart`         | every session        | runtime.env, git-identity.env, gitconfig          | static.env, token + meta                  |
| Pre-tool-use    | `PreToolUse`           | every Bash tool call | runtime.env (token only)                          | static.env, token + meta                  |

The Setup hook is the **only** writer of static config. SessionStart and
PreToolUse exclusively read it; they never re-derive APP_ID etc. from process
env. This prevents cross-agent env contamination from poisoning the static
inputs.

The Setup-hook precedent is established by `shared-lib` (the only other plugin
in this marketplace using `Setup{matcher: init}`). The agent launcher fires
`claude --init-only` once per plugin install/version change before the
interactive session starts, which makes Setup the right place for one-time
per-version provisioning.

### File layout

All files live under a single XDG-style subdirectory:

```
${AGENT_CONFIG_DIR}/github-app/
├── static.env              # immutable inputs — written by Setup only
├── runtime.env             # mutable token+identity — rewritten on each refresh
├── git-identity.env        # stable git identity vars — written once per session
├── token                   # current installation token (chmod 600)
├── token.meta              # JSON metadata (expiry, app_slug, bot_id, ...)
├── private-key.pem         # PEM (only when key was provided as content)
├── git/config              # isolated gitconfig (GIT_CONFIG_GLOBAL points here)
├── gh/                     # isolated GH_CONFIG_DIR (kept empty intentionally)
└── last-check              # PreToolUse debounce timestamp
```

`${AGENT_CONFIG_DIR}` resolves to `${HOME}/.agents/${AGENT_NAME}/.config`.

The flat `${AGENT_CONFIG_DIR}/github-app-env` file from <=0.3.5 is removed by
the migration step (see "Migration" below).

### static.env contents

Written exactly once per Setup run. Contains only values that must not change
during a session and are NEVER re-read from process env after Setup:

```sh
export GITHUB_APP_ID="..."
export GITHUB_INSTALLATION_ID="..."
export GITHUB_APP_PRIVATE_KEY_PATH="..."     # always an absolute path
export GITHUB_APP_CLIENT_ID="..."            # optional, when present in vault
export GITHUB_APP_CLIENT_SECRET="..."        # optional, when present in vault
# Provenance (used for diagnostics only):
export GITHUB_APP_STATIC_REF="op://..."      # the ref:/secrets.* source identity
export GITHUB_APP_STATIC_WRITTEN_AT="2026-05-06T17:23:11Z"
```

Permissions: 600. The file IS sourced by SessionStart and PreToolUse via
`source` directly (NOT via `CLAUDE_ENV_FILE`), so subprocesses do not inherit
the static values unless they explicitly source the file too. (Inheriting
`GITHUB_APP_ID` into arbitrary child processes is harmless, but we restrict the
surface area to the hooks that need it.)

### runtime.env contents

Written by SessionStart on every session and by PreToolUse on every successful
refresh. Contains only mutable per-session/per-refresh values:

```sh
export GH_TOKEN="..."
export GITHUB_TOKEN="..."
export GITHUB_TOKEN_FILE="${AGENT_CONFIG_DIR}/github-app/token"
export GITHUB_APP_ENV_FILE="${AGENT_CONFIG_DIR}/github-app/runtime.env"
export GH_CONFIG_DIR="${AGENT_CONFIG_DIR}/github-app/gh"
export GIT_CONFIG_GLOBAL="${AGENT_CONFIG_DIR}/github-app/git/config"
export GIT_AUTHOR_NAME="..."
export GIT_AUTHOR_EMAIL="..."
export GIT_COMMITTER_NAME="..."
export GIT_COMMITTER_EMAIL="..."
```

Critically: **no `GITHUB_APP_ID`, no `GITHUB_INSTALLATION_ID`, no
`GITHUB_APP_PRIVATE_KEY_PATH`**. Those live in static.env exclusively. There is
no path by which a contaminated process env can flow into the rewritten
runtime.env's static fields, because the runtime writer doesn't have those
fields.

This file IS sourced via `CLAUDE_ENV_FILE` so each Bash tool call sees the
fresh token.

### Path derivation hardening

`lib/agent-paths.sh` becomes:

```sh
# AGENT_NAME must be set to a non-empty value other than "_UNKNOWN".
if [[ -z "${AGENT_NAME:-}" || "${AGENT_NAME}" == "_UNKNOWN" ]]; then
  echo "github-app: ERROR: AGENT_NAME is unset or _UNKNOWN — refusing to derive paths" >&2
  echo "github-app: ERROR: set AGENT_NAME in the agent launcher before invoking Claude Code" >&2
  return 1 2>/dev/null || exit 1
fi
AGENT_CONFIG_DIR="${HOME}/.agents/${AGENT_NAME}/.config"
GITHUB_APP_CONFIG_DIR="${AGENT_CONFIG_DIR}/github-app"
```

This eliminates the silent fallback that would put one agent's files in
`~/.agents/_UNKNOWN/.config/` (shared between every misconfigured agent).
Misconfiguration becomes loud and recoverable rather than silently corrupting
state.

### Setup hook (`hooks/scripts/install.sh`)

Registered as `Setup{matcher: init}` in `hooks/hooks.json`. Fires once per
`claude --init-only` invocation, which the launcher runs on plugin install or
version change.

Steps:

1. Source `lib/agent-paths.sh` — fails loud if `AGENT_NAME` unset.
2. Source `lib/plugin-config-read.sh` from shared-lib data dir.
3. Resolve `enabled` config; exit 0 if disabled.
4. Resolve `ref:` and `secrets.*` from plugin config — **NEVER from process env
   for the static fields** (see Goals #1). Fail loud if any required field
   missing.
   - `ref: op://...` → resolve every required field via `op read`.
   - `ref: env-file://...` → source the file in a subshell, copy values out.
   - `secrets.*` overrides take priority per existing semantics.
5. Resolve `GITHUB_APP_PRIVATE_KEY_PATH`:
   - If a literal path was configured, canonicalize it with `realpath`.
   - If only `GITHUB_APP_PRIVATE_KEY` (content) is configured, write it to
     `${GITHUB_APP_CONFIG_DIR}/private-key.pem` with chmod 600.
6. Validate the PEM file exists and has restrictive permissions.
7. Write `static.env` atomically (`mktemp` + `mv`) with chmod 600.
8. Generate the initial installation token by invoking
   `bin/generate-token.sh` with the resolved arguments. Writes `token` and
   `token.meta`.
9. Run migration cleanup (see "Migration").
10. Print a one-line summary; exit 0.

If Setup fails, the next `claude --init-only` retries from scratch. There is
no cooldown for Setup itself.

### SessionStart hook (`hooks/scripts/session-start.sh`, renamed from

`github-token-init.sh`)

1. Source `lib/agent-paths.sh` (fails loud on unknown agent).
2. Source `lib/plugin-config-read.sh`; exit 0 if disabled.
3. If `${GITHUB_APP_CONFIG_DIR}/static.env` does not exist:
   - Log a warning instructing the operator to run `claude --init-only` (or
     reinstall the plugin), then call `install.sh` directly as a fallback so
     existing sessions don't break in the wild. This makes the Setup hook a
     fast path, not a hard requirement.
4. `source "${GITHUB_APP_CONFIG_DIR}/static.env"` — this is the **only**
   source of `GITHUB_APP_ID`, `GITHUB_INSTALLATION_ID`,
   `GITHUB_APP_PRIVATE_KEY_PATH` for this hook's process.
5. Determine token state via `lib/token-utils.sh::get_minutes_remaining`:
   - `missing|expired` → call `bin/generate-token.sh` (full re-auth from PEM).
   - valid but `<= 45 min` → call `bin/token-check.sh --sync` (refresh).
   - valid → no-op for token, just rewrite runtime.env.
     If refresh fails, fall back to `generate-token` (so the initial token's 1h
     TTL having expired by the next session is harmless).
6. Resolve the bot identity from `token.meta` (`app_slug`, `bot_id`). If
   `bot_id` missing, fall back to the existing public-`/users/<slug>[bot]`
   resolution. If still unresolvable, refuse to write git identity (existing
   BUG-7 fail-loud behavior).
7. Call `write_runtime_env_file` and `write_git_identity_file` with the resolved
   token and bot identity. Call `write_git_config_global` to refresh the
   isolated gitconfig.
8. Append two lines to `CLAUDE_ENV_FILE` so subsequent Bash tool calls inherit
   the runtime + identity:
   ```sh
   source "${GITHUB_APP_CONFIG_DIR}/runtime.env"
   source "${GITHUB_APP_CONFIG_DIR}/git-identity.env"
   ```

### PreToolUse hook (`hooks/scripts/pre-tool-use.sh`, renamed from

`github-token-check.sh`)

1. Source `lib/agent-paths.sh`.
2. Source `static.env` to get APP_ID/INSTALLATION_ID/PEM_PATH (NOT from process
   env — same anti-contamination guarantee). If `static.env` missing → exit 0
   (plugin not yet provisioned, defer to SessionStart).
3. Check token via `get_minutes_remaining`.
4. On expired/expiring, invoke `bin/token-check.sh --sync --quiet` which
   internally calls `generate-token.sh` and rewrites runtime.env (token only).
5. PreToolUse NEVER touches static.env.

### `lib/env-file.sh` refactor

Split into:

- `write_static_env_file()` — new. Called only by `install.sh`. Writes the
  static fields from explicit local arguments (NOT from `${VAR:-}` lookups), so
  there is no path for process env to leak in.
- `write_runtime_env_file(token)` — refactored. Writes ONLY the runtime fields
  enumerated above. Removes all references to `GITHUB_APP_ID`,
  `GITHUB_INSTALLATION_ID`, `GITHUB_APP_PRIVATE_KEY_PATH`,
  `GITHUB_APP_CLIENT_ID`, `GITHUB_APP_CLIENT_SECRET`.
- `read_static_env_file()` — new. `source`s the static file with strict
  checking; errors if any required field is missing.

`_safe_val` is preserved as-is.

### Migration

When `install.sh` runs (and as a one-shot in SessionStart's fallback path):

1. If `${AGENT_CONFIG_DIR}/github-app-env` exists (old layout):
   - Log: `github-app: removing legacy env file from <pre-0.4.0> layout`.
   - `rm -f` it.
2. If `${AGENT_CONFIG_DIR}/github-token` and `.meta` exist at the old top-level
   path (no subdir), the new layout writes fresh files at the subdir path. The
   old token files are left in place but become orphans; SessionStart's
   `last-check` debounce file from the old path is also left as an orphan.
   These are harmless and self-pruning on the next agent reset; we don't try to
   diff/migrate token state because tokens are short-lived (1h) and Setup
   regenerates them.

The migration is idempotent: re-running install.sh on an already-migrated agent
is a no-op for cleanup steps.

### Settings/config compatibility

`github-app.settings.yaml` is unchanged. The `ref:`, `secrets.*`,
`autoGitConfig`, `tokenFile`, etc. keys all behave the same way they did in
0.3.5. The only difference is **where** the resolved values are written. The
`tokenFile` setting, if set, is honored as before but the default moves from
`${AGENT_CONFIG_DIR}/github-token` to `${AGENT_CONFIG_DIR}/github-app/token`.

## Test plan

### Unit-ish (no external API)

- `lib/agent-paths.sh` exits non-zero when `AGENT_NAME` is unset or `_UNKNOWN`.
- `lib/env-file.sh::write_runtime_env_file` does NOT emit `GITHUB_APP_ID` or
  `GITHUB_APP_PRIVATE_KEY_PATH` lines.
- `lib/env-file.sh::write_static_env_file` writes the expected fields and
  chmods 600.
- `lib/env-file.sh::read_static_env_file` errors when a field is missing.
- Migration: pre-0.4.0 layout (file at `${AGENT_CONFIG_DIR}/github-app-env`)
  is removed after install.sh runs; new layout exists.

### Integration (mocked op + real openssl)

- Setup with `ref: op://...` resolves all five fields, writes static.env,
  generates token. Use a fixture PEM and a mocked `op` shim.
- SessionStart, when run in a process where `GITHUB_APP_ID` is set to a
  WRONG value in env, still writes the CORRECT value into runtime files — i.e.
  the contamination-resistance regression test. This is the BUG-19 reproducer.

### CI

The plugin's existing CI runs `bash -n` and shellcheck across `bin/`, `lib/`,
and `hooks/scripts/`. New scripts must pass shellcheck-clean.

### Manual on a real agent

1. On Jack's host: `claude plugin update github-app` (after merge).
2. Verify Setup writes `${AGENT_CONFIG_DIR}/github-app/static.env` with Jack's
   APP_ID 2638903 / installation 118953149.
3. Start a new session, verify `gh api user` returns `jack-nsheaps[bot]` and
   `git log -1 --format=%ae` shows Jack's bot email.
4. Restart, verify token regenerates from static.env without re-reading env.
5. On Alex's host: same steps with Alex's IDs. Confirm they no longer collide.

## Migration risks

| Risk                                               | Mitigation                                                       |
| -------------------------------------------------- | ---------------------------------------------------------------- |
| Existing sessions running 0.3.5 mid-flight         | SessionStart fallback calls install.sh if static.env missing     |
| `tokenFile` setting overrides the new default path | Honored unchanged; migration only touches the default location   |
| User has manually placed a PEM at the old path     | Setup canonicalizes any configured path; doesn't move user PEMs  |
| Old `github-app-env` was the only proof-of-config  | Setup re-resolves from `ref:`/`secrets.*`, so it is reproducible |

## Version

Plugin version bump: **0.3.5 → 0.4.0**. Breaking layout change (file paths
within `${AGENT_CONFIG_DIR}` move into a subdirectory; the old flat env file is
deleted on first install of 0.4.0).

## References

- BUG-19 — empirical reproduction (2026-05-06).
- BUG-7 — git identity resolution (existing fail-loud behavior preserved).
- shared-lib `Setup{matcher: init}` precedent —
  `plugins/shared-lib/hooks/hooks.json` and `hooks/scripts/sync-lib.sh`.
- Anthropic plugin reference: persistent data directory + Setup event —
  https://code.claude.com/docs/en/plugins-reference#persistent-data-directory
