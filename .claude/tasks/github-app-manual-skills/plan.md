# Task: Add manual-operation skills to the `github-app` plugin

## Goal

The `github-app` plugin performs its work automatically through two hooks
(`SessionStart` → `github-token-init.sh`, `PreToolUse` → `github-token-check.sh`).
When those hooks don't run (hook disabled, race timed out, new/foreign shell,
agent-team teammate, debugging), an agent needs to reproduce each operation by
hand. Add skills covering **all the things the plugin does** so they can be done
manually.

## What the plugin does (operation inventory)

| Operation                                                      | Implemented by                              | Manual coverage today |
| -------------------------------------------------------------- | ------------------------------------------- | --------------------- |
| Materialize PEM from `GITHUB_APP_PRIVATE_KEY`                  | init hook / token-check                     | partial (token skill) |
| Generate / exchange installation token                         | `bin/generate-token.sh`                     | ✅ `github-app-token` |
| Refresh / status of token                                      | `bin/token-check.sh`, `bin/token-status.sh` | ✅ `github-app-token` |
| Write runtime env file (`GH_TOKEN`/`GITHUB_TOKEN`/…)           | `lib/env-file.sh`                           | ❌ none               |
| Wire `CLAUDE_ENV_FILE` so every Bash call sees the token       | init hook                                   | ❌ none               |
| `GH_CONFIG_DIR` isolation                                      | init hook                                   | ❌ none               |
| Resolve bot identity (`app_slug` + `bot_id`)                   | `generate-token.sh` / init hook             | ❌ none               |
| Configure git identity (`GIT_AUTHOR_*`/`GIT_COMMITTER_*`)      | init hook                                   | ❌ none               |
| Isolated `GIT_CONFIG_GLOBAL` + `gh auth git-credential` helper | `lib/env-file.sh`                           | partial snippet only  |

## Approach

Add **two focused skills** that, together with the existing `github-app-token`
skill, cover the full inventory without redundancy:

1. **`github-app-session-env`** — make the token usable in the current session
   by hand: materialize PEM → ensure token → `GH_CONFIG_DIR` isolation →
   write runtime env file → wire `CLAUDE_ENV_FILE`. The "the hook didn't run /
   `GH_TOKEN` isn't in my env" runbook.

2. **`github-app-git-identity`** — configure the bot git identity by hand:
   resolve `app_slug` + `bot_id`, build `<slug>[bot]` name + noreply email,
   set `GIT_*` env vars, write isolated `GIT_CONFIG_GLOBAL` with the
   `gh auth git-credential` helper. Carries the BUG-7 subtlety (App ID ≠ bot
   user ID; `/users/<slug>[bot]` must be called with NO auth header) in a
   `references/` file.

Both reuse the plugin's existing `bin/` scripts and `lib/` functions (DRY) —
the skills document the procedure and call the shipped code, they don't
re-derive JWT/openssl logic.

Keep the existing `github-app-token` skill as the token-lifecycle authority;
add cross-links to/from the two new skills.

## Deliverables

- `skills/github-app-session-env/SKILL.md`
- `skills/github-app-git-identity/SKILL.md`
- `skills/github-app-git-identity/references/bot-identity-internals.md`
- Cross-link from `skills/github-app-token/SKILL.md`
- Update `SPEC.md` and `README.md` to list the new skills
- Bump `plugin.json` 0.5.1 → 0.6.0 (minor — additive)

## Validation

- `mise run validate` (plugin structure)
- `mise run lint` (markdown/format)
- Manual re-read of each SKILL.md against the actual `bin/`/`lib/` behavior

## References

- Plugin source: `plugins/github-app/{bin,lib,hooks}/`
- Skill authoring: `plugin-dev:skill-development`
