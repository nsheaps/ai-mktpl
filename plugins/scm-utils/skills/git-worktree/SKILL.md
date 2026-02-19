---
name: git-worktree
description: Best practices for using Git worktrees, especially when checking out PRs or working with multiple worktrees simultaneously.
---

# Git Worktree Best Practices

## Branch Naming Rule

When checking out a PR (or any remote branch) into a worktree, the local branch name **MUST** match the remote branch name exactly.

**Correct:**
```bash
# PR branch is "feature/my-change"
git worktree add ../worktrees/pr-42 feature/my-change
# or
gh pr checkout 42  # automatically uses the correct branch name
```

**Wrong:**
```bash
# PR branch is "feature/my-change" but you use a different local name
git worktree add -b pr-review ../worktrees/pr-42 origin/feature/my-change
```

## Why Mismatches Are Dangerous

Git's worktree protection prevents checking out the same branch in two worktrees simultaneously. But this protection is based on **local branch name**, not tracking ref.

If you create a local branch `pr-review` tracking `origin/feature/my-change`, Git will happily let another worktree also check out `origin/feature/my-change` under a different local name (e.g., `pr-review-2`). This causes:

- **Conflicting pushes**: Both worktrees push to the same remote ref, overwriting each other's work.
- **Lost commits**: Force-pushes from one worktree silently discard commits from the other.
- **Confusing state**: `git status` looks clean in both worktrees, hiding the conflict entirely.

When local names match the remote name, Git blocks the second checkout:
```
fatal: 'feature/my-change' is already checked out at '/path/to/other/worktree'
```

This is the protection you want.

## How to Check Out PRs Correctly

**Preferred -- use `gh pr checkout`:**
```bash
# From within any worktree for the repo
gh pr checkout 42
```
This automatically creates a local branch with the correct name matching the remote.

**Manual checkout:**
```bash
git checkout -b feature/my-change origin/feature/my-change
```
Or when creating a new worktree:
```bash
git worktree add ../worktrees/pr-42 -b feature/my-change origin/feature/my-change
```
The key is that the `-b` name matches the remote branch name exactly.

## Worktree Directory Naming

The worktree **directory name** can be anything descriptive -- it does not need to match the branch name. Use whatever helps you identify the worktree's purpose:

```bash
git worktree add ../worktrees/pr-42 feature/my-change        # by PR number
git worktree add ../worktrees/fix-auth feature/fix-auth-flow  # by description
git worktree add ../worktrees/review feature/my-change        # by purpose
```

The branch inside the worktree is what must match the remote. The directory is just a folder on disk.

## References

- [Git Worktrees Documentation](https://git-scm.com/docs/git-worktree)
- [GitHub CLI `gh pr checkout`](https://cli.github.com/manual/gh_pr_checkout)
