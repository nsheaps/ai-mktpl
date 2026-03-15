---
name: rebase
description: Rebase a feature branch onto its base branch to produce a linear commit history. Use when the user asks to "rebase my branch", "rebase onto main", "rebase PR #123", "linearize history", "rebase and force push", or when a clean linear history is preferred over merge commits.
argument-hint: [PR number | PR URL | branch name | directory]
---

# Rebase Branch

Rebase a feature branch onto its base branch to produce a clean, linear commit history.

## Overview

This skill rebases a feature branch on top of its base branch instead of merging. Use rebase when:

- The project or user prefers linear history (no merge commits)
- A PR review requested rebasing before merge
- Cleaning up history before final merge

**Key difference from update-branch:** The `update-branch` skill uses `git merge` (preserves history, no force push needed). This skill uses `git rebase` (rewrites history, requires force push).

## Input Resolution

**Default behavior (no arguments):** Use the current directory, get the current branch via `git branch --show-current`, find the associated PR via `gh pr list --head <branch>`, and rebase onto the PR's base branch.

Determine the target branch from the provided input. Accept any of:

| Input Type  | Example                                | Resolution                                              |
| ----------- | -------------------------------------- | ------------------------------------------------------- |
| No input    | (empty)                                | Current directory → current branch → find PR → rebase   |
| PR number   | `123`, `#123`                          | `gh pr view 123 --json headRefName,baseRefName`         |
| PR URL      | `https://github.com/org/repo/pull/123` | Parse number, use `gh pr view`                          |
| Branch name | `feature/my-branch`                    | Use directly, find PR with `gh pr list --head <branch>` |
| Directory   | `/path/to/repo`                        | `cd` there, get current branch, find PR                 |

**Critical:** Always query the PR to determine the base branch. Never assume `main` or `master`.

```bash
# Get branch info from PR
gh pr view <number> --json headRefName,baseRefName,number,url

# Find PR for a branch
gh pr list --head <branch-name> --json number,baseRefName --limit 1
```

## Rebase Workflow

Execute these steps in order:

### Step 1: Pre-flight Checks

Ensure the working tree is clean before rebasing:

```bash
git status --porcelain
```

If there are uncommitted changes, **stop and ask the user** whether to stash, commit, or abort. A rebase with a dirty working tree will fail.

### Step 2: Fetch Latest

```bash
git fetch --all --prune
```

### Step 3: Get Base Branch from PR

```bash
BASE_BRANCH=$(gh pr view <number> --json baseRefName --jq '.baseRefName')
```

If no PR exists for the branch, ask the user what the base branch should be.

### Step 4: Ensure on Correct Branch

```bash
git checkout <feature-branch>
```

### Step 5: Pull Remote Feature Branch Changes

Before rebasing, incorporate any remote changes to the feature branch:

```bash
git pull origin <feature-branch> --rebase
```

### Step 6: Rebase onto Base Branch

```bash
git rebase origin/$BASE_BRANCH
```

If conflicts occur, see [Conflict Resolution](#conflict-resolution).

### Step 7: Force Push with Lease

Since rebase rewrites history, a force push is required. **Always use `--force-with-lease`** to prevent overwriting others' work:

```bash
git push --force-with-lease origin <feature-branch>
```

**NEVER use `--force`** — `--force-with-lease` will fail safely if the remote has commits you haven't seen.

### Step 8: Verify

Confirm the remote branch is updated:

```bash
gh pr view <number> --json commits,mergeable,mergeStateStatus
```

## Conflict Resolution

Rebase applies commits one at a time, so conflicts must be resolved per-commit.

### During Rebase Conflicts

When a conflict occurs mid-rebase:

```bash
# See which files conflict
git diff --name-only --diff-filter=U

# After resolving conflicts in a file
git add <file>

# Continue the rebase
git rebase --continue
```

To abort and return to the pre-rebase state:

```bash
git rebase --abort
```

### Obvious Conflicts

Resolve directly when the conflict is clearly one of:

- Formatting differences (whitespace, line endings)
- Simple additions that don't overlap semantically
- Deleted code that was also modified (keep modification or deletion based on intent)
- Import statement ordering

### Non-Obvious Conflicts

For conflicts requiring analysis, delegate to specialized agents:

1. **Use Explore agent** with haiku model to understand:
   - What each side of the conflict is trying to accomplish
   - The history of the conflicting changes
   - Related code that might inform the resolution

2. **Use Plan agent** to determine:
   - The correct resolution strategy
   - Whether both changes can coexist
   - If architectural decisions are needed

3. **Execute the resolution** — the executing agent owns the final resolution.

4. **Stage and continue:**
   ```bash
   git add <resolved-files>
   git rebase --continue
   ```

5. **Verify the resolution** — run tests or builds after the full rebase completes.

For detailed conflict patterns, see the update-branch skill's `references/conflict-resolution.md`.

## Safety Rules

**Only modify the requested branch:**

- ONLY rebase the specific PR/branch that was requested
- Do NOT recursively rebase parent PRs
- If the base branch is itself a feature branch, rebase onto it as-is

**Force push safely:**

- **ALWAYS** use `--force-with-lease` (never bare `--force`)
- `--force-with-lease` fails if the remote has unexpected commits, preventing data loss
- If `--force-with-lease` fails, fetch and inspect before retrying

**Confirm before force pushing shared branches:**

- If the feature branch has multiple contributors (check with `git log --format='%an' origin/<branch> | sort -u`), **warn the user** that rebase will rewrite their collaborators' history
- Collaborators will need to `git pull --rebase` or reset their local branch after the force push

**Preserve all commits:**

- After rebase, verify the same number of feature-branch commits exist (unless squashing was requested)
- Compare `git log --oneline origin/$BASE_BRANCH..<feature-branch>` before and after

**When NOT to rebase:**

- The branch is shared with other active contributors (prefer merge)
- The branch has already been merged elsewhere
- The user explicitly asked for merge (use `update-branch` skill instead)

## Error Handling

| Error                              | Resolution                                                     |
| ---------------------------------- | -------------------------------------------------------------- |
| No PR found for branch             | Ask user for base branch, or create PR first                   |
| Dirty working tree                 | Ask user to stash or commit first                              |
| Rebase conflicts                   | Resolve per-commit, then `git rebase --continue`               |
| `--force-with-lease` rejected      | Fetch, inspect new remote commits, ask user how to proceed     |
| Rebase produces empty commits      | Use `git rebase --skip` for truly empty commits                |
| Authentication failure             | Ensure `gh` and `git` are authenticated                        |

## CI/Remote Environment Usage

This skill works identically in CI and local environments:

- Use `git` directly for all operations
- Git identity configuration is outside this skill's scope
- The CI environment should configure `user.name` and `user.email` appropriately
