# scm-utils

Source control management utilities for improving Claude's interactions with branches and PRs, both locally and in CI environments.

## Skills

All skills are invocable via `/skill-name` syntax (e.g., `/commit`, `/rebase`).

### commit

Intelligently commit outstanding changes in logical, focused commits.

```
/commit [optional hint]
```

Analyzes all changes, groups them into logical commits, and uses angular-style commit messages. The optional hint guides grouping strategy or content focus.

### code-review

Request a code review or set up automated PR review via CI.

```
/code-review [PR number | PR URL | branch name]
```

If the repository has the Claude review bot CI workflow (`.github/workflows/claude-code-review.yaml`), adds the `request-review` label to trigger it. Otherwise, performs a local review.

Also covers setup, configuration, and troubleshooting of the review bot.

**Reference files included:**

- `references/workflow-template.yaml` — Complete GitHub Actions workflow
- `references/prompt-template.md` — Review prompt with interpolation variables
- `references/labels.yaml` — GitHub labels for review triggers
- `references/copilot-instructions.md` — Fallback instructions for when the review workflow itself is modified

**Requirements:**

- GitHub App with contents:write, pull-requests:write, issues:write permissions
- Secrets: `REVIEW_GITHUB_APP_ID`, `REVIEW_GITHUB_APP_PRIVATE_KEY`, `REVIEW_ANTHROPIC_API_KEY` (or `ANTHROPIC_API_KEY`)

### update-branch

Synchronize a branch with its base using merge (preserves history).

```
/update-branch [pr-number|url|branch|directory]
```

**Default behavior (no arguments):** Uses current directory, gets current branch, finds associated PR, and updates from the PR's base branch.

**What it does:**

1. Resolves the target branch from PR number, URL, branch name, or current directory
2. Fetches the base branch from PR metadata (never assumes)
3. Merges base branch into the feature branch
4. Pulls remote changes to local (merge strategy)
5. Pushes local changes back to remote
6. Handles merge conflicts intelligently using Explore/Plan agents for non-obvious cases

**Safety:**

- Only modifies the requested branch — does NOT recursively update parent PRs
- Never uses `--force`
- Prefers merge over rebase to preserve history
- Only uses `--force-with-lease` or `--force-if-includes` when absolutely necessary

### rebase

Rebase a feature branch onto its base branch for linear commit history.

```
/rebase [PR number | PR URL | branch name | directory]
```

**Default behavior (no arguments):** Uses current directory, gets current branch, finds associated PR, and rebases onto the PR's base branch.

**Key difference from update-branch:** `update-branch` uses `git merge` (preserves history, no force push). `rebase` uses `git rebase` (rewrites history, requires force push with `--force-with-lease`).

**Safety:**

- Always uses `--force-with-lease` (never bare `--force`)
- Warns about shared branches with multiple contributors
- Does NOT recursively rebase parent PRs
- Verifies commit count preservation after rebase

## Installation

Add to your Claude Code plugins:

```bash
cc --plugin-dir /path/to/scm-utils
```

Or install from the marketplace (when available).

## Requirements

- `git` - Git CLI
- `gh` - GitHub CLI (for PR metadata, labels, reviews)
