# Automatic PR Creation and Updates

## Rule: Every Branch Gets a PR

**All sessions MUST automatically create and maintain a pull request for their working branch.**

## When to Create a PR

Create a PR **after the first push** to a new branch. Do not wait for the user to ask.

## When to Update a PR

Update the PR description **after every push** to reflect the current state of changes. Keep the description accurate and up-to-date as work progresses.

## How to Authenticate

Use the `GH_TOKEN` environment variable with the `gh` CLI. Since the git remote in web sessions is a local proxy, use `gh api` with `--hostname github.com` for all GitHub API calls (not `gh pr create` which requires a GitHub remote).

The `gh` CLI should already be configured via the mise-managed GitHub plugin. If `gh` is not available, install it via `mise install`.

## Creating a PR

**Always create PRs as drafts.** After creation, add the `request-review` label to trigger an AI code review.

- Target the default branch (usually `main`) unless the task specifies otherwise
- Include a session link if available (format: `https://claude.ai/code/session_XXXXX`)

## Updating an Existing PR

After subsequent pushes, update the PR body to reflect all changes.

## Checking for an Existing PR

Before creating, check if a PR already exists for the current branch. If one exists, update it instead of creating a new one. Use server-side filtering (e.g. `?head=nsheaps:<branch-name>&state=open`) for efficiency.

## PR Title Conventions

- Keep under 70 characters
- Start with a verb (Add, Fix, Update, Refactor, etc.)
- Match conventional commit style when applicable

## PR Lifecycle

1. **Create as draft** — all new PRs start as drafts
2. **Add `request-review` label** — triggers AI code review automatically
3. **Address review feedback** — fix any issues found by the AI review
4. **Mark ready** when work is complete and CI passes

## See Also

- [Authentication & Tokens](auth.md) - GH_TOKEN configuration and scope
- [CI/CD Conventions](ci-cd/conventions.md) - Accessing GitHub API in web sessions
- [GitHub Issues & Labels](github-issues-task-management.md) - Label management (including `request-review`)
