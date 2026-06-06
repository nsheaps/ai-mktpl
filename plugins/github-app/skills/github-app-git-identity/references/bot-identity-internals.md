# Bot Identity Internals (BUG-7)

Background on why the `github-app` plugin resolves the bot git identity the way
it does. This is the detail that is easy to get wrong when configuring identity
by hand. The shipped code lives in `bin/generate-token.sh` (resolution at
token-generation time) and `configure_git_identity_env` in
`hooks/scripts/github-token-init.sh` (runtime fallback + gitconfig).

## The core mistake: App ID ≠ bot user ID

A GitHub App has an **App ID** (the `GITHUB_APP_ID` used to mint the JWT). The
App's bot account (`<slug>[bot]`) is a separate GitHub **user** with its own
numeric **user ID**. These are different numbers.

GitHub attributes a commit to the bot account only when the author email is the
bot user's noreply address:

```
<bot_user_id>+<slug>[bot]@users.noreply.github.com
```

If the email instead embeds the **App ID**, the commit is accepted by git but is
**not** linked to the bot account on GitHub — it shows as an unattributed author.
Because the App ID and bot user ID are both plausible-looking integers, this
failure is silent and only visible after the fact on github.com. Rewriting
history is the only fix once miscredited commits are pushed.

## Resolving the bot user ID

Two endpoints are involved, with different auth requirements:

| Endpoint                     | Auth                    | Returns                 |
| ---------------------------- | ----------------------- | ----------------------- |
| `GET /app`                   | JWT (App-as-app) Bearer | `.slug` (the app slug)  |
| `GET /users/<slug>%5Bbot%5D` | **none**                | `.id` (the bot user ID) |

Key points:

- The installation **token** cannot call `/app` — only the JWT can. That is why
  `bin/generate-token.sh` resolves the slug while the JWT is still valid and
  caches `app_slug` + `bot_id` into `github-token.meta`. Downstream consumers
  read the metadata instead of minting a new JWT.
- `/users/<slug>[bot]` is a **public** users endpoint. Sending an
  `Authorization` header (the JWT bearer or the installation token) makes it
  return **401**. It must be called **unauthenticated**. `[bot]` is URL-encoded
  as `%5Bbot%5D`.

## Fail loud, never guess

When the bot user ID cannot be resolved (no metadata, API unreachable), the
plugin **refuses** to configure git identity rather than fall back to the App
ID. The trade-off:

- **Refuse** → the next `git commit` fails with `Author identity unknown`. Loud,
  immediate, and recoverable (fix network/API, regenerate, retry).
- **Guess (App ID)** → commits succeed but are silently miscredited. Not
  recoverable without rewriting pushed history.

The loud failure is strictly better. When configuring identity manually, follow
the same rule: if `bot_id` cannot be resolved, stop and fix the root cause — do
not substitute the App ID.

## Config isolation (why `GIT_CONFIG_GLOBAL` is overridden)

On shared machines every agent runs as the same OS user and inherits the
handler's `~/.gitconfig`. To prevent agents committing as the handler, the
plugin writes a per-agent gitconfig at `$CLAUDE_PLUGIN_DATA/git/config` and
points `GIT_CONFIG_GLOBAL` at it. `GIT_AUTHOR_*`/`GIT_COMMITTER_*` env vars are
also set as defense-in-depth — they take precedence over gitconfig, so identity
holds even if `GIT_CONFIG_GLOBAL` is somehow bypassed. This mirrors the
`GH_CONFIG_DIR` isolation used for the `gh` CLI.

## Credential helper

The gitconfig credential helper is written as:

```ini
[credential "https://github.com"]
    helper =
    helper = !gh auth git-credential
```

The empty `helper =` first resets any previously configured helper, then the
second line installs the gh-based one. `gh auth git-credential` reads `GH_TOKEN`
from the process environment at credential-request time (kept fresh via
`CLAUDE_ENV_FILE`), so the gitconfig contains **no** token and **no** versioned
script path — it never needs rewriting when the token refreshes or `gh` upgrades.
`gh` must be on `PATH`; otherwise `write_git_config_global` returns non-zero and
writes no `[credential]` section.

## Source references

- `plugins/github-app/bin/generate-token.sh` — JWT mint, `/app` slug lookup,
  public `/users/<slug>[bot]` ID lookup, metadata write
- `plugins/github-app/hooks/scripts/github-token-init.sh` —
  `configure_git_identity_env`: runtime `bot_id` fallback, fail-loud guard,
  env-var + gitconfig wiring
- `plugins/github-app/lib/env-file.sh` — `write_git_config_global`,
  `write_git_identity_file`, `write_runtime_env_file`
