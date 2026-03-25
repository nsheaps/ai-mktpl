---
name: making-great-prs
description: >
  Best practices and procedures for creating and maintaining high-quality pull requests.
  Covers PR creation, body formatting, title conventions, and lifecycle management.
  Triggers on: "create a PR", "update the PR", "open a pull request", "push and PR",
  "fix PR", "fix PR body", "PR formatting", or automatically after any push to a
  feature branch per the auto-pr-management rule.
allowed-tools: Bash, Read, Grep, Glob
---

# Making Great PRs

Create and maintain pull requests for feature branches. The github plugin sets `GH_HOST` and `GH_REPO` automatically in web sessions, so standard `gh` subcommands work everywhere.

## Pre-fetched Context

Current branch: !`git branch --show-current 2>/dev/null || echo "(not in a git repo)"`

## Prerequisites

```bash
eval "$(mise activate bash)"
```

The `gh` CLI must be available (installed via mise) and `GH_TOKEN` must be set in the environment.

## Step 1: Check for Existing PR

Always check before creating to avoid duplicates:

```bash
gh pr list --head "<branch-name>" --state open --json number,title --jq '.[0]'
```

If a PR already exists, skip to [Step 3: Update PR](#step-3-update-pr).

## Step 2: Create Draft PR

```bash
PR_URL=$(gh pr create \
  --draft \
  --title "Short descriptive title" \
  --body "$(cat <<'PREOF'
## Summary
- What changed and why

## Test plan
- [ ] Verification steps

<!-- Include Claude Code session link if available, e.g.: https://claude.ai/code/session_XXXXX -->
PREOF
)")
```

Then add the `request-review` label to trigger AI code review:

```bash
PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$')
gh pr edit "$PR_NUMBER" --add-label "request-review"
```

## Step 3: Update PR

After subsequent pushes, update the PR body to reflect all current changes:

```bash
gh pr edit <PR_NUMBER> --body "$(cat <<'PREOF'
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
gh pr ready <PR_NUMBER>
```

## PR Title Conventions

- Keep under 70 characters
- Start with a verb (Add, Fix, Update, Refactor, etc.)
- Match conventional commit style when applicable

## PR Body Formatting

**CRITICAL:** PR bodies must contain real newlines, not literal `\n` escape sequences.

- When using `gh api`, use heredocs (`$(cat <<'PREOF' ... PREOF)`) — they preserve newlines naturally
- When using MCP tools (e.g. `mcp__github__create_pull_request`), pass the body as a multi-line string with actual newlines — MCP tool string parameters support real newlines
- **Never** construct PR bodies by concatenating strings with `\n` — GitHub renders them as literal text, not line breaks

## Error Handling

| Error                 | Resolution                                                         |
| --------------------- | ------------------------------------------------------------------ |
| `gh` not found        | Run `eval "$(mise activate bash)"` or `mise install`               |
| 401 Unauthorized      | Check `GH_TOKEN` is set and has PR write scope                     |
| 422 Validation failed | Branch may not exist on remote yet — push first                    |
| PR already exists     | Use `gh pr edit` to update instead of `gh pr create`               |
| Host/repo not found   | Ensure `GH_HOST` and `GH_REPO` are set (automatic in web sessions) |
