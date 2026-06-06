---
name: github-app-git-identity
description: >
  Manually configure the GitHub App bot git identity the way the github-app
  plugin's SessionStart hook does — resolve the app slug and bot user ID, build
  the <slug>[bot] name and noreply email, set GIT_AUTHOR_*/GIT_COMMITTER_* env
  vars, and write an isolated GIT_CONFIG_GLOBAL with the gh auth git-credential
  helper. Use when commits are attributed to the wrong account, "Author identity
  unknown" appears, or git identity must be set up by hand.
  <example>my commits are showing up as the handler, not the bot</example>
  <example>git says Author identity unknown after the github-app hook ran</example>
  <example>configure the github app bot git identity manually</example>
  <example>set up the gh credential helper for git push</example>
---

# GitHub App Git Identity (Manual)

This skill reproduces `configure_git_identity_env` from the `github-app`
SessionStart hook (`hooks/scripts/github-token-init.sh`) by hand. The end state
is: commits authored as `<app-slug>[bot]` with the correct GitHub noreply email
(so GitHub attributes them to the bot account), plus an isolated
`GIT_CONFIG_GLOBAL` whose `credential.helper` is `!gh auth git-credential`.

This is the identity/credential layer. For making the token usable in the
session (PEM, env file, `CLAUDE_ENV_FILE`, `GH_CONFIG_DIR`) use the
`github-app-session-env` skill first — a valid token + metadata must already
exist before identity can be resolved.

## When To Use

- Commits are attributed to the handler/host user instead of the bot.
- `git commit` fails with `Author identity unknown`.
- The hook logged `Could not resolve bot user ID` and refused to set identity.
- A git push needs the `gh auth git-credential` helper wired up manually.

## The One Subtlety That Matters (BUG-7)

The App ID is **not** the bot user ID. Commits whose noreply email embeds the
App ID are silently **not** attributed to the bot on GitHub. The correct email
uses the bot user's numeric ID from the **public** `/users/<slug>[bot]`
endpoint, which must be called with **no** `Authorization` header. Full rationale
and the fail-loud reasoning are in
[`references/bot-identity-internals.md`](references/bot-identity-internals.md).

## Prerequisites

A token and its metadata already exist (run `github-app-session-env` if not):

```bash
CLAUDE_PLUGIN_DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/github-app-ai-mktpl}"
META_FILE="$CLAUDE_PLUGIN_DATA/github-token.meta"
test -f "$META_FILE" && echo "metadata present" || echo "run github-app-session-env first"
```

## Procedure

### Step 1 — Read app slug and bot ID from metadata

`bin/generate-token.sh` already resolves these (it holds JWT auth needed for the
`/app` endpoint) and stores them in the metadata file:

```bash
app_slug="$(jq -r '.app_slug // empty' "$META_FILE")"
bot_id="$(jq -r '.bot_id // empty' "$META_FILE")"
echo "slug=$app_slug bot_id=$bot_id"
```

If `app_slug` is empty, regenerate the token so metadata is repopulated
(`bin/token-check.sh --sync`, or delete `github-token.meta` and regenerate).

### Step 2 — Resolve `bot_id` at runtime if missing

Older metadata or an API hiccup at generation time can leave `bot_id` empty.
Resolve it via the **public** users endpoint — **do not** send an auth header
(a bearer token there returns 401):

```bash
if [[ -z "$bot_id" && -n "$app_slug" ]]; then
  bot_id="$(curl -s -H 'Accept: application/vnd.github+json' \
    "https://api.github.com/users/${app_slug}%5Bbot%5D" | jq -r '.id // empty')"
  echo "resolved bot_id=$bot_id"
fi
```

If `bot_id` still cannot be resolved, **stop** — do not fall back to the App ID.
Fix network/API access and retry. See the reference doc for why miscredited
commits are worse than failing loud.

### Step 3 — Build the identity values

```bash
bot_name="${app_slug}[bot]"
bot_email="${bot_id}+${app_slug}[bot]@users.noreply.github.com"
echo "$bot_name <$bot_email>"
```

### Step 4 — Set env vars + write the isolated gitconfig

Export the identity (these take precedence over gitconfig) and reuse the
plugin's `write_git_config_global` helper, which writes an isolated
`GIT_CONFIG_GLOBAL` with the `[user]` block and the `gh auth git-credential`
helper. `write_git_config_global` reads `GIT_AUTHOR_NAME`/`GIT_AUTHOR_EMAIL` and
the target `GIT_CONFIG_GLOBAL` path from the environment:

```bash
export GIT_AUTHOR_NAME="$bot_name"
export GIT_AUTHOR_EMAIL="$bot_email"
export GIT_COMMITTER_NAME="$bot_name"
export GIT_COMMITTER_EMAIL="$bot_email"
export GIT_CONFIG_GLOBAL="$CLAUDE_PLUGIN_DATA/git/config"

source "$CLAUDE_PLUGIN_ROOT/lib/env-file.sh"
write_git_config_global        # writes [user] + credential.helper = !gh auth git-credential
```

`write_git_config_global` requires `gh` on `PATH` (it returns non-zero and
writes no `[credential]` section otherwise). It does not embed a token or a
versioned script path — `gh` reads `GH_TOKEN` from the env at credential time.

### Step 5 — Persist a stable identity file + wire `CLAUDE_ENV_FILE`

Write the stable identity file (not overwritten by token refresh) and re-write
the runtime env file so the `GIT_*` vars are captured, then wire both into
`CLAUDE_ENV_FILE`:

```bash
export TOKEN_FILE="$CLAUDE_PLUGIN_DATA/github-token"
export ENV_RUNTIME_FILE="$CLAUDE_PLUGIN_DATA/github-app-env"

write_git_identity_file "$bot_name" "$bot_email"   # -> $CLAUDE_PLUGIN_DATA/github-git-identity
write_runtime_env_file "$(cat "$TOKEN_FILE")"      # re-capture GIT_* into the env file

if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
  echo "export GIT_CONFIG_GLOBAL=\"$GIT_CONFIG_GLOBAL\"" >> "$CLAUDE_ENV_FILE"
  echo "source \"$CLAUDE_PLUGIN_DATA/github-git-identity\"" >> "$CLAUDE_ENV_FILE"
fi
```

## Verify

```bash
git var GIT_AUTHOR_IDENT     # -> <slug>[bot] <id+slug[bot]@users.noreply.github.com> ...
git config --get user.email  # matches bot_email (reads isolated GIT_CONFIG_GLOBAL)

# Bot account check (never print the raw token)
GH_TOKEN="$(cat "$CLAUDE_PLUGIN_DATA/github-token")" gh api /user --jq '.login'
# Expected: <slug>[bot]
```

After a real commit, `git log -1 --format='%an <%ae>'` should show the bot
identity, and the commit should be attributed to the bot account on GitHub.

## Common Failures

| Symptom                                                    | Likely cause                                                                   |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------ |
| Commits credited to the handler                            | `GIT_CONFIG_GLOBAL` not isolated, or host `~/.gitconfig` leaking — redo Step 4 |
| Commits not linked to the bot on GitHub                    | Email used App ID instead of bot user ID — re-resolve `bot_id` (Steps 2–3)     |
| `Author identity unknown`                                  | Identity never set — run Steps 3–4                                             |
| `write_git_config_global` writes no `[credential]` section | `gh` not on `PATH` — install/expose `gh`, re-run                               |
| `/users/<slug>[bot]` returns 401                           | An `Authorization` header was sent — it must be called unauthenticated         |

## Related

- **`github-app-session-env`** — PEM, token, env file, `CLAUDE_ENV_FILE`, `GH_CONFIG_DIR`
- **`github-app-token`** — token generation, refresh, status
- [`references/bot-identity-internals.md`](references/bot-identity-internals.md) — why App ID ≠ bot user ID, the unauthenticated-endpoint rule, fail-loud rationale
- Plugin source: `lib/env-file.sh` (`write_git_config_global`, `write_git_identity_file`),
  `bin/generate-token.sh`, `hooks/scripts/github-token-init.sh`
