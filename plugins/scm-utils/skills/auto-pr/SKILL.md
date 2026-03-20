---
name: auto-pr
description: >
  Automatically create or update a pull request for the current branch.
  Use after pushing commits to ensure a PR exists and its description is current.
  Triggers on: "create a PR", "update the PR", "open a pull request", "push and PR",
  or automatically after any push to a feature branch per the auto-pr-management rule.
allowed-tools: Bash, Read, Grep, Glob
---

# Auto PR Management

Create and maintain pull requests for feature branches using `gh api` with `--hostname github.com` (required for web sessions where the git remote is a local proxy).

## Pre-fetched Context

Current branch: !`git branch --show-current 2>/dev/null || echo "(not in a git repo)"`

## Prerequisites

```bash
eval "$(mise activate bash)"
```

The `gh` CLI must be available (installed via mise) and `GH_TOKEN` must be set in the environment.

## Step 1: Check for Existing PR

Always check before creating to avoid duplicates. Use server-side filtering:

```bash
gh api "repos/nsheaps/ai-mktpl/pulls?head=nsheaps:<branch-name>&state=open" \
  --hostname github.com \
  --jq '.[0] | {number, title, state}'
```

If a PR already exists, skip to [Step 3: Update PR](#step-3-update-pr).

## Step 2: Create Draft PR

```bash
PR_NUMBER=$(gh api repos/nsheaps/ai-mktpl/pulls \
  --hostname github.com \
  --method POST \
  --field title="Short descriptive title" \
  --field head="<branch-name>" \
  --field base="main" \
  --field draft=true \
  --field body="$(cat <<'PREOF'
## Summary
- What changed and why

## Test plan
- [ ] Verification steps

<!-- Include Claude Code session link if available, e.g.: https://claude.ai/code/session_XXXXX -->
PREOF
)" --jq '.number')
```

Then add the `request-review` label to trigger AI code review:

```bash
gh api repos/nsheaps/ai-mktpl/issues/${PR_NUMBER}/labels \
  --hostname github.com \
  --method POST \
  --field 'labels[]=request-review'
```

## Step 3: Update PR

After subsequent pushes, update the PR body to reflect all current changes:

```bash
gh api repos/nsheaps/ai-mktpl/pulls/<PR_NUMBER> \
  --hostname github.com \
  --method PATCH \
  --field body="$(cat <<'PREOF'
## Summary
- Updated description reflecting all changes

## Test plan
- [ ] Updated verification steps

<!-- session link -->
PREOF
)"
```

## Step 4: Mark Ready (When Complete)

Only after review feedback is addressed and CI passes:

```bash
gh api repos/nsheaps/ai-mktpl/pulls/<PR_NUMBER> \
  --hostname github.com \
  --method PATCH \
  --field draft=false
```

## PR Title Conventions

- Keep under 70 characters
- Start with a verb (Add, Fix, Update, Refactor, etc.)
- Match conventional commit style when applicable

## Error Handling

| Error                 | Resolution                                           |
| --------------------- | ---------------------------------------------------- |
| `gh` not found        | Run `eval "$(mise activate bash)"` or `mise install` |
| 401 Unauthorized      | Check `GH_TOKEN` is set and has PR write scope       |
| 422 Validation failed | Branch may not exist on remote yet — push first      |
| PR already exists     | Use PATCH to update instead of POST to create        |
