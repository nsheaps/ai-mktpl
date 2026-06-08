# Take over PR #290 — reconstruct on fresh branch

## Context

[PR #290](https://github.com/nsheaps/ai-mktpl/pull/290) "Fix GitHub plugin context for web
session proxy" (head `claude/fix-github-plugin-context-BbrcW`, Closes #296) adds automatic
`GH_HOST`/`GH_REPO` export in the github plugin's SessionStart hook so `gh` subcommands work
in web sessions (where the git remote is a local proxy).

**Problem:** `main` was re-rooted/rewritten after the PR opened. PR #290's branch shares **no
common ancestor** with current `main` (different root commits) and is very stale (predates the
`shared/lib → plugins/shared-lib` migration, telegram plugin, `SPEC.md` files). A normal
merge/rebase is impossible. Per handler decision, reconstruct the PR's net feature on a fresh
branch off current `main`.

## Auth

`GH_TOKEN` from the environment was invalid (401). Authenticated instead via the **github-app +
1pass** plugins: generated a GitHub App installation token from `op://Agent-Jack/github--app--jack`
(app id 2638903, installation 118953149) using `plugins/github-app/bin/generate-token.sh`.

## Scope (reconstructed on `claude/beautiful-dijkstra-vnYLb` off `main`)

Faithful to PR #290's primary intent (#296), adapted to current main's wording:

1. `plugins/github/hooks/scripts/install-gh.sh` — append the `GH_HOST`/`GH_REPO` env-var block
   to `do_install` (core feature; main's `do_install` matches the PR's up to the auth-check).
2. `plugins/github/skills/gh/SKILL.md` — insert the self-contained "Web Sessions" section
   (env-var approach primary, `gh api --hostname` fallback) after the intro.
3. `.claude/rules/auto-pr-management.md` — surgical: replace `--hostname` workaround wording with
   the GH_HOST/GH_REPO hook description; fix existing-PR check example to `gh pr list`.
4. `.claude/rules/ci-cd/conventions.md` — surgical: update the CI-status and "Accessing GitHub in
   Web Sessions" blocks to use plain `gh` subcommands.
5. `.claude/rules/workflow-self-improvement.md` — new rule (verbatim from PR).
6. `plugins/github/.claude-plugin/plugin.json` — version bump 0.1.17 → 0.2.0 (minor; feature).

### Excluded (deliberate, with reasons)

- **`mise.toml` op-exec comment-out (#293):** current main has `github:nsheaps/op-exec = "0.1.0"`
  active again; re-commenting risks regressing whatever resolved #293. Out of scope for #296.
- **scm-utils version bump:** main (0.2.3) is already far ahead of the PR's 0.1.14; no content change.
- **Scattered per-command `--hostname` notes in gh SKILL.md:** low-value, high-churn against a
  diverged file; the new "Web Sessions" section removes the doc contradiction without them.

## Validation

- `mise run lint`
- `mise run validate`

## Delivery

- Push `claude/beautiful-dijkstra-vnYLb`; open **draft** PR targeting `main`, body `Closes #296`,
  note it supersedes #290; add `request-review` label.
- Comment on #290 pointing to the new PR, then close #290 (handler authorized supersede/close).
