# scm-utils

Source control management utilities for improving Claude's interactions with branches and PRs, both locally and in CI environments.

## Commands

### /code-review

Request or trigger a code review for a pull request.

```
/code-review [PR number | PR URL | branch name]
```

If the repository has the Claude review bot CI workflow, adds the `request-review` label to trigger it. Otherwise, performs a local review.

### /update-branch

Synchronize a branch with its base and push all changes.

```
/update-branch [pr-number|url|branch|directory]
```

**Default behavior (no arguments):** Uses current directory, gets current branch, finds associated PR, and updates from the PR's base branch.

## Skills

### code-review

Automated PR review system powered by [claude-code-action](https://github.com/anthropics/claude-code-action) running in GitHub Actions. Covers setup, configuration, and troubleshooting of the review bot.

**Triggers on:**

- "set up review bot"
- "configure code review CI"
- "how does the review bot work"
- "add automated PR review"
- "review bot"
- "code review CI"

**Reference files included:**

- `references/workflow-template.yaml` — Complete GitHub Actions workflow
- `references/prompt-template.md` — Review prompt with interpolation variables
- `references/labels.yaml` — GitHub labels for review triggers
- `references/copilot-instructions.md` — Fallback instructions for when the review workflow itself is modified

**Requirements:**

- GitHub App with contents:write, pull-requests:write, issues:write permissions
- Secrets: `REVIEW_GITHUB_APP_ID`, `REVIEW_GITHUB_APP_PRIVATE_KEY`, `REVIEW_ANTHROPIC_API_KEY` (or `ANTHROPIC_API_KEY`)

### update-branch

Synchronizes a local branch with its remote counterpart and ensures the remote branch is up-to-date with its base branch.

**Triggers on:**

- "update the PR"
- "update PR #123"
- "sync the branch"
- "update the branch"
- "merge base into feature branch"
- "get latest from main"

**What it does:**

1. Resolves the target branch from PR number, URL, branch name, or current directory
2. Fetches the base branch from PR metadata (never assumes)
3. Merges base branch into the feature branch
4. Pulls remote changes to local (merge strategy)
5. Pushes local changes back to remote
6. Handles merge conflicts intelligently using Explore/Plan agents for non-obvious cases

**Safety:**

- Only modifies the requested branch - does NOT recursively update parent PRs
- Never uses `--force`
- Prefers merge over rebase to preserve history
- Only uses `--force-with-lease` or `--force-if-includes` when absolutely necessary

## Installation

Add to your Claude Code plugins:

```bash
cc --plugin-dir /path/to/scm-utils
```

Or install from the marketplace (when available).

## Requirements

- `git` - Git CLI
- `gh` - GitHub CLI (for PR metadata, labels, reviews)
