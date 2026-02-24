---
name: git-worktree
description: >
  Best practices for Git worktrees, especially branch naming when checking out
  PRs. Use this when creating worktrees, checking out PRs into worktrees, or
  working in multi-agent/multi-worktree setups.
argument-hint: [pr-number|branch-name]
---

# Git Worktree Best Practices

## Branch Naming Rule

When checking out a PR or remote branch into a worktree, the **local branch name MUST match the remote branch name exactly**.

```bash
# CORRECT: local branch matches remote
git worktree add ../repo.worktrees/pr-42 feature/my-change
#                                        ^^^^^^^^^^^^^^^^^ matches origin/feature/my-change

# WRONG: invented local name tracking a differently-named remote
git worktree add ../repo.worktrees/pr-42 -b pr-review --track origin/feature/my-change
#                                           ^^^^^^^^^ does NOT match remote name
```

## Why Mismatches Are Dangerous

Git's worktree protection prevents the **same local branch** from being checked out in two worktrees simultaneously. But this protection is based on local branch name, not tracking ref.

If you create a local branch `pr-review` tracking `origin/feature/my-change`, git will happily let another worktree also check out `origin/feature/my-change` under a different local name (e.g., `pr-review-2`). This causes:

- **Conflicting pushes** -- two worktrees pushing to the same remote branch
- **Lost work** -- force-pushes from one worktree silently overwrite the other
- **Confusing state** -- `git branch` shows separate branches that are actually the same remote ref

Matching names means git's built-in protection works correctly: if `feature/my-change` is already checked out in a worktree, git will refuse to check it out again anywhere else.

## How to Check Out PRs Correctly

### Preferred: Use `gh pr checkout`

```bash
# From within an existing worktree or clone
gh pr checkout 42
```

`gh pr checkout` automatically creates a local branch with the correct remote name.

### Manual: Match the remote branch name exactly

```bash
git worktree add ../repo.worktrees/pr-42 -b feature/my-change origin/feature/my-change
```

Or if the branch already exists locally:

```bash
git worktree add ../repo.worktrees/pr-42 feature/my-change
```

### For new worktrees from a PR number

```bash
# 1. Get the branch name
BRANCH=$(gh pr view 42 --json headRefName --jq '.headRefName')

# 2. Fetch and create worktree with matching branch name
git fetch origin "$BRANCH"
git worktree add ../repo.worktrees/pr-42 -b "$BRANCH" "origin/$BRANCH"
```

## Worktree Directory Naming

The **worktree directory name** can be anything descriptive -- it does not need to match the branch. Common conventions:

| Convention        | Example                       |
| ----------------- | ----------------------------- |
| PR number         | `repo.worktrees/pr-42`        |
| Short description | `repo.worktrees/fix-auth`     |
| Agent name        | `repo.worktrees/agent-tweety` |

The directory name is just a filesystem path. The **branch name inside** is what must match the remote.

## Cleanup

Always remove worktrees when done to unblock the branch for other checkouts:

```bash
# From the main repo (NOT from inside the worktree)
git worktree remove ../repo.worktrees/pr-42
```

## References

- [Git worktree documentation](https://git-scm.com/docs/git-worktree)
- For git-spice + worktree workflows, see the `git-spice` plugin's `git-spice` skill
