---
name: github-app-session-env
description: >
  Manually reproduce what the github-app plugin's SessionStart hook does to make
  a GitHub App installation token usable in the current session — materialize the
  PEM, generate the token, isolate GH_CONFIG_DIR, write the runtime env file, and
  wire CLAUDE_ENV_FILE so every Bash call sees GH_TOKEN/GITHUB_TOKEN. Use when the
  hook did not run, the token is missing from the environment, or a shell/teammate
  needs the token wired up by hand.
  <example>GH_TOKEN isn't set even though github-app is configured</example>
  <example>the github-app SessionStart hook didn't run, set up the token manually</example>
  <example>wire the github app token into CLAUDE_ENV_FILE</example>
  <example>gh keeps falling back to the wrong account, isolate GH_CONFIG_DIR</example>
---

# GitHub App Session Env Setup (Manual)

This skill reproduces, by hand, the session wiring the `github-app` plugin's
SessionStart hook (`hooks/scripts/github-token-init.sh`) performs. The end state
is: a valid installation token on disk, an isolated `gh` config, a runtime env
file, and `CLAUDE_ENV_FILE` sourcing it so `GH_TOKEN`/`GITHUB_TOKEN` are present
in every subsequent Bash command.

For token **generation/refresh/status mechanics** see the `github-app-token`
skill. For **bot git identity** (commit attribution) see the
`github-app-git-identity` skill. This skill is the env/session plumbing that
sits between them.

## When To Use

- The SessionStart hook did not run (plugin disabled, env-var race timed out,
  manual/foreign shell, agent-team teammate started without the hook).
- `GH_TOKEN` / `GITHUB_TOKEN` are missing even though the three credential env
  vars are present.
- `gh` is resolving the wrong account because `GH_CONFIG_DIR` is not isolated.
- A new long-lived background shell needs the token wired in.

## Paths And Conventions

All runtime files live under `$CLAUDE_PLUGIN_DATA/` (per-agent isolated). Outside
a hook, `CLAUDE_PLUGIN_DATA` may be unset — fall back to the deterministic path:

```bash
CLAUDE_PLUGIN_DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/github-app-ai-mktpl}"
mkdir -p "$CLAUDE_PLUGIN_DATA"
```

| File                | Purpose                                        |
| ------------------- | ---------------------------------------------- |
| `github-app.pem`    | Materialized private key (mode 600)            |
| `github-token`      | Raw installation token (mode 600)              |
| `github-token.meta` | JSON: `expires_at`, `app_slug`, `bot_id`, …    |
| `github-app-env`    | Runtime env file sourced via `CLAUDE_ENV_FILE` |
| `gh/`               | Isolated `GH_CONFIG_DIR`                       |

## Prerequisites

Confirm the three credential env vars are present (length-only — never print
secret values):

```bash
for v in GITHUB_APP_ID GITHUB_INSTALLATION_ID GITHUB_APP_PRIVATE_KEY; do
  val="${!v:-}"
  [[ -n "$val" ]] && echo "$v is set (${#val} chars)" || echo "$v is NOT set"
done
```

If any are missing, the token cannot be generated — inject them first (the 1pass
plugin is the recommended mechanism; see the plugin README).

## Procedure

### Step 1 — Materialize the PEM

The plugin writes the key from the env var to disk on every session start (never
cached across sessions):

```bash
printf '%s\n' "$GITHUB_APP_PRIVATE_KEY" > "$CLAUDE_PLUGIN_DATA/github-app.pem"
chmod 600 "$CLAUDE_PLUGIN_DATA/github-app.pem"
```

### Step 2 — Ensure a valid token

Prefer the shipped refresh script — it handles generation, retries, cooldown,
and rewrites the runtime env file:

```bash
"$CLAUDE_PLUGIN_ROOT/bin/token-check.sh" --sync
```

Exit codes: `0` valid/refreshed · `1` failed after retries · `2` not configured
· `3` in cooldown. If `CLAUDE_PLUGIN_ROOT` is unset (outside a hook), call
`bin/generate-token.sh` directly as documented in the `github-app-token` skill.
On success `github-token` and `github-token.meta` exist under
`$CLAUDE_PLUGIN_DATA/`.

### Step 3 — Isolate `GH_CONFIG_DIR`

Give `gh` an empty per-agent config dir so it never falls back to the handler's
keyring when the App token expires:

```bash
export GH_CONFIG_DIR="$CLAUDE_PLUGIN_DATA/gh"
mkdir -p "$GH_CONFIG_DIR"
chmod 700 "$GH_CONFIG_DIR"
```

### Step 4 — Write the runtime env file

Reuse the plugin's `write_runtime_env_file` helper so the file matches exactly
what the hook produces (token vars + `GITHUB_TOKEN_FILE`, `GITHUB_APP_ENV_FILE`,
`GH_CONFIG_DIR`, and any already-exported `GIT_*` identity vars), with proper
shell-escaping:

```bash
export TOKEN_FILE="$CLAUDE_PLUGIN_DATA/github-token"
export ENV_RUNTIME_FILE="$CLAUDE_PLUGIN_DATA/github-app-env"
source "$CLAUDE_PLUGIN_ROOT/lib/env-file.sh"
write_runtime_env_file "$(cat "$TOKEN_FILE")"
```

`write_runtime_env_file` requires `TOKEN_FILE` and `ENV_RUNTIME_FILE` to be set
before it is called, and reads optional `GITHUB_APP_ID`, `GITHUB_INSTALLATION_ID`,
`GH_CONFIG_DIR`, and `GIT_*` vars from the environment.

### Step 5 — Wire `CLAUDE_ENV_FILE`

So every later Bash command picks up the token (and re-reads it after a refresh):

```bash
if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
  echo "source \"$CLAUDE_PLUGIN_DATA/github-app-env\"" >> "$CLAUDE_ENV_FILE"
fi
```

Without `CLAUDE_ENV_FILE` (a plain shell), source the env file directly instead:
`source "$CLAUDE_PLUGIN_DATA/github-app-env"`.

## Verify

```bash
# Token present and reports the bot identity (never print the raw token)
GH_TOKEN="$(cat "$CLAUDE_PLUGIN_DATA/github-token")" gh api /user --jq '.login'
# Expected: <app-slug>[bot]

# Status JSON (expiry, minutes remaining, app/installation)
"$CLAUDE_PLUGIN_ROOT/bin/token-status.sh"
```

In a fresh Bash call (after Step 5), `echo "${GH_TOKEN:+set} ${GITHUB_TOKEN:+set}"`
should print `set set`.

## Troubleshooting

| Symptom                                  | Likely cause / fix                                                                                 |
| ---------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `GH_TOKEN` still unset in new Bash calls | Step 5 skipped, or `CLAUDE_ENV_FILE` unset — source `github-app-env` directly                      |
| `token-check.sh` exits `2`               | Credential env vars missing — re-check prerequisites                                               |
| `token-check.sh` exits `3`               | Cooldown after repeated failures — `rm "$CLAUDE_PLUGIN_DATA/github-token.cooldown"` then retry     |
| `gh` uses the wrong account              | `GH_CONFIG_DIR` not isolated/exported — redo Step 3 and re-source the env file                     |
| env file has empty `GIT_*` vars          | Identity not configured yet — run the `github-app-git-identity` skill, which rewrites the env file |

## Related

- **`github-app-token`** — token generation, refresh, status, and failure table
- **`github-app-git-identity`** — bot commit attribution + credential helper
- **`github-auth`** — general GitHub authentication methods
- Plugin source: `bin/token-check.sh`, `bin/generate-token.sh`, `lib/env-file.sh`,
  `hooks/scripts/github-token-init.sh`
