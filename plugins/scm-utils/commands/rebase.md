---
description: Rebase a branch onto its base branch for linear history
argument-hint: [pr-number|url|branch|directory]
allowed-tools: Bash, Read, Grep, Glob, Task
---

Rebase the target branch onto its base branch for a clean, linear commit history.

**Load the rebase skill** from scm-utils for the complete workflow.

## Input Resolution

Determine the target from the argument (or use defaults):

- **No argument**: Use current directory, get current branch via `git branch --show-current`, find associated PR
- **PR number** (e.g., `123`, `#123`): Use `gh pr view 123` to get branch info
- **PR URL** (e.g., `https://github.com/org/repo/pull/123`): Parse PR number, use `gh pr view`
- **Branch name** (e.g., `feature/my-branch`): Find PR with `gh pr list --head <branch>`
- **Directory path**: Change to directory, get current branch, find PR

Argument provided: $ARGUMENTS

## Pre-fetched Context (dynamic injection)

Current branch: !`git branch --show-current 2>/dev/null || echo "(not in a git repo)"`

Working tree status: !`git status --porcelain 2>/dev/null | head -5 || echo "(not in a git repo)"`

PR info for current branch:
!`gh pr view --json baseRefName,headRefName,number,title,state 2>/dev/null || echo "(no PR found or gh not authenticated)"`

## Execute the Workflow

1. Verify working tree is clean (abort if dirty — ask user to stash or commit)
2. Fetch all remotes
3. Get base branch from PR metadata (never assume)
4. Pull remote feature branch changes with `--rebase`
5. Rebase onto base branch: `git rebase origin/$BASE_BRANCH`
6. Force push with lease: `git push --force-with-lease origin <feature-branch>`
7. Verify the PR is updated

## Safety Reminders

- ONLY rebase the requested branch — do NOT recursively rebase parent PRs
- **ALWAYS** use `--force-with-lease` (never bare `--force`)
- If the branch has multiple contributors, warn before force pushing
- If `--force-with-lease` is rejected, fetch and inspect before retrying

## Conflict Handling

Rebase applies commits one at a time. For each conflict:

- For obvious conflicts (formatting, simple additions): resolve directly, `git add`, `git rebase --continue`
- For non-obvious conflicts: use Explore agent to understand both sides, Plan agent to determine resolution
- To abort: `git rebase --abort`

## Completion Messaging

When reporting completion, be explicit about what happened:

**Do say:** "Rebased feature branch onto main — force pushed with lease to update remote"

**Don't say:** "Branch updated" (ambiguous — could be merge or rebase)
