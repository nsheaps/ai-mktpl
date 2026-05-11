# 1pass envLocal target spec

## Problem

The 1pass plugin currently writes resolved secrets to one of:

| Target                                          | Destination                            |
| ----------------------------------------------- | -------------------------------------- |
| `sessionStartBashEnv`                           | `$CLAUDE_ENV_FILE`                     |
| `userSettings`                                  | `~/.claude/settings.local.json` `.env` |
| `envFile`, `settings*Json` (individual secrets) | as named above                         |

Handler directive (Discord, 2026-05-11): static creds managed by 1pass should
live in `$AGENT_HOME_DIR/.env.local` (gitignored, persistent, idempotent), with
the chain:

```
CLAUDE_ENV_FILE  →  $AGENT_HOME_DIR/.env  →  $AGENT_HOME_DIR/.env.local
```

So Claude Code (via `CLAUDE_ENV_FILE`) and other consumers (direnv, `bash`
sessions sourcing `$AGENT_HOME_DIR/.env`) get the same vars.

Constraints:

1. `$AGENT_HOME_DIR/.env.local` MUST NOT be wiped each session — idempotent
   replace-or-append semantics only. Other tools, or the user, may also write
   to this file and their entries must survive.
2. The plugin appends `source $AGENT_HOME_DIR/.env` (or a configurable
   alternative) to `$CLAUDE_ENV_FILE` so the chain reaches Claude Code.
3. Existing targets (`sessionStartBashEnv`, `userSettings`, `envFile`,
   `settingsJson`, `settingsLocalJson`, `userSettingsJson`) keep current
   behavior. The new target is additive.

## Design

Add a new target `envLocal` to:

- `opExec.targets` (whole-item op-exec injection)
- `secrets[].target` (individual secret entries)

Top-level config:

```yaml
1pass:
  envLocal:
    path: "$AGENT_HOME_DIR/.env.local" # default; falls back to $CLAUDE_PROJECT_DIR/.env.local
    sourceChain: "$AGENT_HOME_DIR/.env" # default; can be 'self', 'none', or a path
```

Behavior:

- For each var sent to `envLocal`, the plugin calls shared-lib's
  `env_file_upsert_export "$envLocal.path" "$KEY" "$VALUE"`. Existing lines
  for `$KEY` are removed; the new line is appended. Other keys are left alone.
- On the first `envLocal` write per session, the plugin also calls
  `env_file_upsert_source "$CLAUDE_ENV_FILE" "$sourceChain"`. If
  `sourceChain == "self"`, the envLocal path itself is sourced.
  If `sourceChain == "none"` (or `"false"`), no source line is added.

## Defaults

| Setting                | Default                                                                 |
| ---------------------- | ----------------------------------------------------------------------- |
| `envLocal.path`        | `$AGENT_HOME_DIR/.env.local`, fallback `$CLAUDE_PROJECT_DIR/.env.local` |
| `envLocal.sourceChain` | `$AGENT_HOME_DIR/.env` when `AGENT_HOME_DIR` is set, else empty         |

`opExec.targets` default stays `[sessionStartBashEnv, userSettings]`.
`envLocal` is opt-in to avoid silently changing behavior for existing users.

## Consumer responsibilities

- `.gitignore`: agent repo must list `.env.local` (and `.env` if applicable).
- `$AGENT_HOME_DIR/.env`: must be templated by the launcher (separate task)
  and contain a line like `source "$AGENT_HOME_DIR/.env.local"` so the chain
  reaches direnv / bash consumers.
- `direnv` `.envrc`: should `source_env "$AGENT_HOME_DIR/.env"` (or
  `dotenv_if_exists`) so non-Claude-Code processes see the vars.

## References

- Handler directive (Discord 2026-05-11)
- Research: `docs/research/claude-env-file-conventions-2026-05-11.md` in the agent-jack repo
- PR #500 (`shared-lib/env-file-helpers`): provides `env_file_upsert_export`
  and `env_file_upsert_source`.
