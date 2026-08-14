# 1pass

Install and manage [1Password CLI](https://developer.1password.com/docs/cli/) (op) and [op-exec](https://github.com/nsheaps/op-exec) in Claude Code sessions.

## Features

- **Auto-install on web sessions**: Installs op to `$project/bin/.local/` on `CLAUDE_CODE_REMOTE=true` sessions
- **op-exec support**: Optionally installs op-exec alongside op
- **Secrets injection**: Inject individual fields (`secrets:`) or whole items (`opExec:`) as env vars at session start
- **Recursive resolution**: `opExec` resolves `op://` references nested in field values (max depth 5) — enables a single-manifest-item pattern
- **Secret redaction**: Concealed values are redacted from tool output
- **Auto-update**: Checks for and installs updates when version is "latest"
- **Background install**: Optional non-blocking installation
- **Comprehensive skills**: Full op CLI and op-exec reference for Claude

## How It Works

On session start (web sessions only):

1. Checks if op is already available on PATH
2. If `autoInstall` is true, downloads the release from 1Password
3. Extracts the binary to `$CLAUDE_PROJECT_DIR/bin/.local/op`
4. Optionally installs op-exec from GitHub releases
5. Adds `bin/.local/` to PATH via `CLAUDE_ENV_FILE`

The `bin/.local/` directory is gitignored, so installed binaries don't pollute the repo.

## Configuration

Create or update `plugins.settings.yaml` at project or user level:

```yaml
# In $CLAUDE_PROJECT_DIR/.claude/plugins.settings.yaml
# or ~/.claude/plugins.settings.yaml

1pass:
  enabled: true # Enable/disable the plugin
  autoInstall: false # Download op if not on PATH (default: false)
  installToProject: true # Install to $project/bin/.local (vs ~/.local/bin)
  backgroundInstall: false # Run install in background
  opVersion: "latest" # Pin a specific op version or use "latest"
  installOpExec: false # Also install op-exec (default: false)
  opExecVersion: "latest" # Pin a specific op-exec version or use "latest"

  # Inject individual 1Password fields as named env vars (see "Secrets Injection")
  secrets: []

  # Inject entire 1Password items as env vars via op-exec (see "Whole-Item Injection")
  opExec:
    items: [] # list of op://vault/item references
    targets: # where to write resolved vars (default: both below)
      - sessionStartBashEnv
      - userSettings

  # File settings for the envLocal target (see "envLocal Configuration")
  envLocal:
    # path: "$AGENT_HOME_DIR/.env.local"
    # sourceChain: "$AGENT_HOME_DIR/.env"
```

## Secrets Injection

The plugin can inject 1Password secrets as environment variables at session start. This works on **all session types** (local and web), as long as `op` is available and authenticated.

### Secrets Configuration

Each secret entry has three fields:

| Field       | Required | Description                                                  |
| ----------- | -------- | ------------------------------------------------------------ |
| `envVar`    | yes      | Environment variable name to set (e.g. `BRAINTRUST_API_KEY`) |
| `reference` | yes      | 1Password secret reference in `op://vault/item/field` format |
| `target`    | no       | Where to write the variable (default: `envFile`)             |

### Target Options

The `target` field controls where the resolved secret value is persisted:

| Target              | File written                                | Scope                                       | Committed to git?                 |
| ------------------- | ------------------------------------------- | ------------------------------------------- | --------------------------------- |
| `envFile` (default) | `$CLAUDE_ENV_FILE`                          | Current session only — gone on next session | No                                |
| `settingsJson`      | `.claude/settings.json` → `env` block       | Persists across sessions                    | **Yes** — visible in repo history |
| `settingsLocalJson` | `.claude/settings.local.json` → `env` block | Persists across sessions                    | No — gitignored                   |
| `userSettingsJson`  | `~/.claude/settings.json` → `env` block     | User-global, persists across all projects   | No — outside repo                 |

**When to use which target:**

- **`envFile`** — Best for most secrets. Session-scoped, no disk persistence, no git risk. Re-injected fresh each session from 1Password. This is the default and recommended target.
- **`settingsLocalJson`** — Use when you need the secret to survive across sessions without re-injection (e.g. if `op` auth is only available during initial setup). The file is gitignored so secrets won't leak to the repo.
- **`userSettingsJson`** — Use for secrets that should be available across all projects for a user. Writes to `~/.claude/settings.json` which is outside any repo. Good for API keys used across multiple projects (e.g. `BRAINTRUST_API_KEY`).
- **`settingsJson`** — Use only for non-sensitive values you want committed. **Never use this for actual secrets** — the file is tracked by git.

### Example

```yaml
1pass:
  enabled: true
  secrets:
    # API key re-injected each session (recommended)
    - envVar: BRAINTRUST_API_KEY
      reference: "op://Personal/Braintrust/api-key"
      target: envFile

    # Persists locally between sessions (gitignored)
    - envVar: DATABASE_URL
      reference: "op://Work/Production DB/connection_string"
      target: settingsLocalJson

    # Non-secret config value committed to repo
    - envVar: SENTRY_ORG
      reference: "op://Work/Sentry/org-slug"
      target: settingsJson

    # target defaults to envFile when omitted
    - envVar: ANTHROPIC_API_KEY
      reference: "op://Work/Claude API Key/credential"
```

## Whole-Item Injection via op-exec

The `secrets:` block above injects **one named field per entry**. The `opExec:`
block does something different: it injects **every field of an entire item at
once** and performs **recursive resolution** of `op://` references found inside
field values. This is the feature to reach for when you want to manage a whole
set of env vars from 1Password without listing each one in plugin config.

At session start, the plugin runs [op-exec](https://github.com/nsheaps/op-exec)
against each configured item. op-exec reads all `STRING` and `CONCEALED` fields,
converts each field label to an environment variable name in UPPER_SNAKE_CASE
(e.g. `"API Key"` → `API_KEY`, `"Database URL"` → `DATABASE_URL`), and writes
the resulting variables to one or more targets.

> Requires op-exec to be available (install via mise, Homebrew, or set
> `installOpExec: true`) and `op` to be authenticated.

### `secrets:` vs `opExec:` — which to use

| Aspect            | `secrets:`                               | `opExec:`                                                     |
| ----------------- | ---------------------------------------- | ------------------------------------------------------------- |
| Granularity       | One field per entry                      | Every field of the whole item                                 |
| Reference format  | `op://vault/item/field` (includes field) | `op://vault/item` (no field)                                  |
| Env var name      | You choose it (`envVar`)                 | Derived from each field label (UPPER_SNAKE_CASE)              |
| Recursive `op://` | No — value is taken literally            | **Yes** — `op://` refs in field values are resolved (depth 5) |
| Underlying tool   | `op read`                                | `op-exec`                                                     |

Use `secrets:` when you need a single value under a name you control. Use
`opExec:` when you want to manage many env vars as fields on a 1Password item,
especially in combination with the recursive-resolution / manifest pattern
described below.

### opExec Configuration

| Field            | Required | Description                                                                   |
| ---------------- | -------- | ----------------------------------------------------------------------------- |
| `opExec.items`   | yes      | List of `op://vault/item` references whose fields become env vars             |
| `opExec.targets` | no       | List of targets to write to (default: `sessionStartBashEnv` + `userSettings`) |

### opExec Targets

`opExec.targets` is a **list** — multiple targets are allowed and all selected
targets receive every resolved variable.

| Target                | File written                             | Scope                                            | Persists across sessions?    | Non-bash tools?    |
| --------------------- | ---------------------------------------- | ------------------------------------------------ | ---------------------------- | ------------------ |
| `sessionStartBashEnv` | Appends to `$CLAUDE_ENV_FILE`            | Bash tool calls only                             | No — session-scoped          | No                 |
| `envLocal`            | Upserts to `envLocal.path` (see below)   | Any consumer that sources the file (e.g. direnv) | Yes — gitignored, idempotent | Yes — when sourced |
| `userSettings`        | `~/.claude/settings.local.json` → `.env` | All Claude Code tools                            | Yes — gitignored             | Yes                |

When `opExec.targets` is omitted, the default is **both** `sessionStartBashEnv`
and `userSettings` — variables are available in bash tool calls and to all other
tools, for the current session and onward. `envLocal` is opt-in.

- **`sessionStartBashEnv`** — Appends `export NAME=value` to `$CLAUDE_ENV_FILE`.
  Since that file is fresh each session, this is a plain append (not an upsert).
  Only bash tool calls inherit it.
- **`envLocal`** — Upserts each variable into the `envLocal.path` file using
  replace-or-append semantics (no truncation), so re-runs and other sources do
  not accumulate duplicates. On its first write of the session the plugin chains
  `envLocal.path` into `$CLAUDE_ENV_FILE` (always), plus an optional secondary
  file configured via `envLocal.sourceChain`. Intended for setups where a
  repo-templated `.env` sources `.env.local` so direnv and other consumers pick
  the vars up. The file is gitignored by the agent repo.
- **`userSettings`** — Writes the variables into the `.env` block of
  `~/.claude/settings.local.json`, which is gitignored and read by all Claude
  Code tools (not just bash). Persists across sessions.

### Recursive resolution (the manifest pattern)

op-exec **always** resolves `op://` references that appear inside a field's
**value**, recursively, up to a **maximum depth of 5**. This behavior is
built into op-exec and is **not configurable**.

This is what makes the whole-item approach powerful. You can keep a single
"manifest" item whose field _values_ are `op://...` references pointing at the
real secrets living in other items:

```
Item "ENVIRONMENT" in vault "MyVault":
  TELEGRAM_BOT_TOKEN = op://MyVault/telegram-bot/token       ← resolved recursively
  DISCORD_BOT_TOKEN  = op://MyVault/discord-bot/token        ← resolved recursively
  DB_HOST            = prod.db.example.com                   ← used as-is (literal)
```

With `opExec.items: ["op://MyVault/ENVIRONMENT"]`, the plugin resolves
`TELEGRAM_BOT_TOKEN` and `DISCORD_BOT_TOKEN` to the actual underlying secret
values, while `DB_HOST` is passed through literally.

**Why this matters:** the plugin config only ever lists the one manifest item.
You add, remove, or re-point secrets by editing fields on that single item in
1Password — no plugin config changes needed. And because the references are
resolved at runtime, **renaming an underlying item only requires updating the
one manifest field that points at it**, not every consumer.

### opExec limitations (inherited from op-exec)

- Only `STRING` and `CONCEALED` fields are exported. Other field types (OTP,
  sections, etc.) are skipped.
- Items must be **flat** — fields organized under sections are not exported.

### opExec Example

```yaml
1pass:
  enabled: true
  installOpExec: true # ensure op-exec is available

  # Where the envLocal target writes (only consulted when envLocal is a target)
  envLocal:
    path: "$AGENT_HOME_DIR/.env.local"
    sourceChain: "$AGENT_HOME_DIR/.env"

  opExec:
    items:
      # Manifest item: fields hold op:// references resolved recursively
      - "op://MyVault/ENVIRONMENT"
      # A flat app-credentials item: each field becomes an env var directly
      - "op://MyVault/my-app-credentials"
    targets:
      - sessionStartBashEnv # session-scoped, bash tools
      - envLocal # persistent, sourced by direnv/templated .env
```

### envLocal Configuration

The `envLocal:` block configures the file used by the `envLocal` target (and by
`secrets:` entries that use `target: envLocal`). It is only consulted when
`envLocal` is selected as a target.

| Field                  | Default                                                                                        | Description                                                                                                                                                                                                                                                   |
| ---------------------- | ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `envLocal.path`        | `$AGENT_HOME_DIR/.env.local` if `AGENT_HOME_DIR` is set, else `$CLAUDE_PROJECT_DIR/.env.local` | Path to the shell-sourceable `.env.local` file (`export K=v` lines). Not truncated each session — uses idempotent replace-or-append.                                                                                                                          |
| `envLocal.sourceChain` | `$AGENT_HOME_DIR/.env` if `AGENT_HOME_DIR` is set, else unset (no secondary source line)       | Path to a **secondary** file chained in via `source <path>` (added to `$CLAUDE_ENV_FILE`). Sentinels: `none` (alias `false`) disables only the secondary chain; `self` points the secondary at `envLocal.path` (a no-op, since that file is already chained). |

> **Note:** The `envLocal.path` file is **always** chained into `$CLAUDE_ENV_FILE`
> on its first write of the session (1pass writes secrets there, so it sources it
> unconditionally). `envLocal.sourceChain` only controls an _additional, secondary_
> file — typically a repo-templated `$AGENT_HOME_DIR/.env` that itself `source`s
> `.env.local` for direnv and other consumers. The secondary file is sourced
> guarded (its absence is a silent no-op), whereas the primary `.env.local` is
> sourced unguarded. Setting `sourceChain: none` therefore disables the secondary
> chain but does **not** stop `.env.local` itself from being sourced.

The agent repo is responsible for gitignoring `.env.local` (and `.env` if used)
and for wiring up the consumer-side `source` of the file.

## Secret Redaction

Concealed secret values injected via `opExec` are tracked and **redacted from
tool output** so they don't leak back into the transcript. During session start,
op-exec writes the `CONCEALED` field values (via its `--concealed-kv-file` flag)
to a private `${CLAUDE_PLUGIN_DATA}/.env.secrets` file (mode 600). Only fields
whose type is `CONCEALED` — or that resolve through a `CONCEALED` `op://`
reference chain — are recorded, so non-secret `STRING` fields are not flagged.

A `PostToolUse` hook (`redact-secrets.sh`) scans each tool's output for those
values and replaces any match with `****REDACTED(ENV_VAR_NAME)****`, plus a
system reminder telling Claude not to repeat the raw value.

> Note: this hook did not fire in the Claude Code CLI on v2.1.128, due to an
> upstream bug
> ([anthropics/claude-code#6305](https://github.com/anthropics/claude-code/issues/6305)).
> Re-tested on v2.1.231 (2026-08-14): `PostToolUse` now fires from a plugin
> `hooks.json`, so redaction is live. Do not rely on the old note — treat
> redaction as active and the transcript as protected accordingly. See
> [`plugins/CLAUDE.md`](../CLAUDE.md) for the test that established this.

## Authentication

The op CLI requires authentication. Options:

- **Service account**: Set `OP_SERVICE_ACCOUNT_TOKEN` environment variable
- **Interactive**: Run `op signin` (local sessions only)
- **Connect server**: Set `OP_CONNECT_HOST` and `OP_CONNECT_TOKEN`

## Using with mise (recommended for this repo)

Instead of auto-install, this repo manages op and op-exec via mise:

```toml
# mise.toml
[tools]
"vfox:mise-plugins/vfox-1password" = "latest"
"github:nsheaps/op-exec" = "latest"
```

## Local Sessions

On local sessions (`CLAUDE_CODE_REMOTE` is not `true`), this plugin does nothing.
It assumes op is already installed locally via Homebrew, mise, or another method.

## Pattern: Project-Local Tool Installation

This plugin follows the **project-local binary** pattern for web sessions:

1. Tools install to `$CLAUDE_PROJECT_DIR/bin/.local/`
2. `bin/.local/` is listed in `.gitignore`
3. The session start hook adds `bin/.local/` to `PATH` via `CLAUDE_ENV_FILE`
4. Each web session gets fresh installs (no persistent state assumed)

This pattern ensures:

- No system-level modifications needed
- No conflicts between projects using different versions
- Clean git state (binaries are gitignored)
- Works in restricted web environments
