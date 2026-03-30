---
name: pr-workflow
description: >
  Full PR lifecycle management: creating, iterating on feedback, and merging.
  Triggers on: "review my PR", "iterate on PR feedback", "address review comments",
  "PR workflow", "get this merged", "respond to reviewer", "handle PR feedback".
allowed-tools: Bash, Read, Grep, Glob
---

# PR Workflow

End-to-end PR lifecycle from creation to merge. See also: `making-great-prs`, `pr-feedback`.

## 1. Create

- Open as **draft** PR, assign handler, add `request-review` label for CI review bot
- See `making-great-prs` skill for PR body format and `gh api` commands

## 2. Review Arrives

- Read **all** feedback threads before doing anything
- Understand the full scope of requested changes before responding

## 3. Respond to Threads First

Before making any code changes, reply to each reviewer thread:

- Acknowledge what you'll fix, OR
- Explain (politely) why you disagree

**NEVER re-request review without responding to all open threads first.**

```bash
gh api repos/<owner>/<repo>/pulls/<PR>/reviews \
  --hostname github.com \
  --method POST \
  --field body="Addressed in latest commit. [details]" \
  --field event="COMMENT"
```

Use `gh pr review --comment` for formal reviews; use inline replies for specific thread responses.

## 4. Fix

- Work in a worktree: `~/src/nsheaps/{repo}.worktrees/{branch}/`
- Commit normally — **NO rebase, NO force push on pushed branches**
- Merge main in if behind: `git merge origin/main`
- Always review the diff of sub-agent changes before reporting the PR as fixed

## 5. Re-Request Review

After responding to all threads AND pushing fixes:

```bash
gh pr edit <PR_NUMBER> --add-label "request-review"
```

Minimize stale review comments where applicable.

## 6. Approved

- Report approval to handler with PR link and CI status
- Include links to CI run and specific log lines if discussing failures
- **NEVER merge without explicit handler approval**
- If you ask "should I merge?", **WAIT for the answer before doing anything**

## 7. Merge

Only after handler explicitly says yes:

```bash
gh pr merge <PR_NUMBER> --squash --delete-branch --hostname github.com
```

## Rules

| Rule                                       | Detail                                                     |
| ------------------------------------------ | ---------------------------------------------------------- |
| No rebase on pushed branches               | Merge main instead                                         |
| No force push                              | Add commits on top                                         |
| Always respond before re-requesting review | Non-negotiable                                             |
| Never merge without handler approval       | **STRIKE ONE** — asking then acting before answer is worse |
| Review sub-agent diffs                     | Before reporting PR as fixed                               |
