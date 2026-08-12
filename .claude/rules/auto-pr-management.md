# Automatic PR Creation and Updates

## Rule: Every Branch Gets a PR

**All sessions MUST automatically create and maintain a pull request for their working branch.**

## When to Create a PR

Create a PR **after the first push** to a new branch. Do not wait for the user to ask.

## When to Update a PR

Update the PR description **after every push** to reflect the current state of changes. Keep the description accurate and up-to-date as work progresses.

## Rebase Before Every Push

**CRITICAL:** Before every push, rebase the branch onto the latest `origin/main`. This is non-negotiable — even if you believe the branch is already up to date.

1. `git fetch origin main`
2. Check if there are upstream commits: `git log --oneline HEAD..origin/main`
3. If there are ANY commits behind, rebase: `git rebase origin/main`
4. Then push (use `--force-with-lease` after a rebase)

**Never skip rebase when the user asks for it.** If the user explicitly requests a rebase, always perform it regardless of whether you think it's needed.

## How to Authenticate

Use the `GH_TOKEN` environment variable with the `gh` CLI. The github plugin's SessionStart hook automatically sets `GH_HOST` and `GH_REPO` in web sessions, so standard `gh` subcommands (`gh pr create`, `gh issue list`, etc.) work normally.

The `gh` CLI should already be configured via the mise or GitHub claude-code plugin. If `gh` is not available, investigate the startup hooks for those plugins.

## Creating a PR

**Always create PRs as drafts.** After creation, add the `request-review` label to trigger an AI code review.

- Target the default branch (usually `main`) unless the task specifies otherwise
- Include a session link if available (format: `https://claude.ai/code/session_XXXXX`)

## Updating an Existing PR

After subsequent pushes, update the PR body to reflect all changes.

## Checking for an Existing PR

Before creating, check if a PR already exists for the current branch. If one exists, update it instead of creating a new one (e.g. `gh pr list --head "<branch-name>" --state open`).

## PR Title Conventions

- Keep under 70 characters
- Start with a verb (Add, Fix, Update, Refactor, etc.)
- Match conventional commit style when applicable

## PR Lifecycle

1. **Create as draft** — all new PRs start as drafts
2. **Add `request-review` label** — triggers AI code review automatically
3. **Address review feedback** — fix any issues found by the AI review (push a fix, or reply in the thread justifying why you're not changing something)
4. **Re-apply `request-review`** to request another review round — the receiver clears the label itself the moment a review starts, so a label sitting on the PR always means "not yet reviewed." Iterate steps 3-4 until the review agent approves.
5. **Gate before human engagement**: only once CI is green, the PR is mergeable (no conflicts), AND the review agent has approved, reach out to the user/handler for their own review — while keeping the PR in draft.

Do not remove-then-re-add the label after every ordinary push just to force a re-trigger — that was only needed before the receiver auto-cleared the label at review start. Re-apply it (add it back if the receiver has cleared it, or remove + re-add if it's somehow still on) specifically when you're requesting a new review round after addressing feedback.

## See Also

- [Authentication & Tokens](auth.md) - GH_TOKEN configuration and scope
- [CI/CD Conventions](ci-cd/conventions.md) - Accessing GitHub API in web sessions
- [GitHub Issues & Labels](github-issues-task-management.md) - Label management (including `request-review`)
