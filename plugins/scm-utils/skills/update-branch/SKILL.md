---
name: update-branch
description: This skill should be used when the user asks to "update the PR", "update PR #123", "sync the branch", "update the branch", "merge base into feature branch", "pull and push changes", "get latest from main", "synchronize with upstream", or when working in CI and needing to synchronize a feature branch with its base. Handles local/remote branch synchronization and merge conflict resolution.
version: 0.1.0
---

# Update Branch

Synchronize a local branch with its remote counterpart and ensure the remote branch is up-to-date with its base branch.

## Overview

This skill handles the common workflow of keeping a feature branch synchronized:

1. Local branch may have unpushed commits
2. Remote branch may have commits not yet pulled
3. Base branch may have advanced since the feature branch was created

The goal: ensure the remote feature branch contains all local changes AND is current with its base branch.

## Input Resolution

**Default behavior (no arguments):** Use the current directory, get the current branch via `git branch --show-current`, find the associated PR via `gh pr list --head <branch>`, and update from the PR's base branch.

Determine the target branch from the provided input. Accept any of:

| Input Type  | Example                                | Resolution                                              |
| ----------- | -------------------------------------- | ------------------------------------------------------- |
| No input    | (empty)                                | Current directory → current branch → find PR → update   |
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

## Synchronization Workflow

Execute these steps in order:

### Step 1: Fetch All Remotes

```bash
git fetch --all --prune
```

### Step 2: Get Base Branch from PR

```bash
# Extract base branch name
BASE_BRANCH=$(gh pr view <number> --json baseRefName --jq '.baseRefName')
```

If no PR exists for the branch, ask the user what the base branch should be.

### Step 3: Ensure on Correct Branch

```bash
git checkout <feature-branch>
```

### Step 4: Merge Base Branch into Feature Branch

```bash
git merge origin/$BASE_BRANCH --no-edit
```

If conflicts occur, see [Conflict Resolution](#conflict-resolution).

### Step 5: Pull Remote Feature Branch

```bash
git pull origin <feature-branch> --no-edit
```

If conflicts occur, handle them before proceeding.

### Step 6: Push to Remote

```bash
git push origin <feature-branch>
```

### Step 7: Verify

Confirm the remote branch is updated:

```bash
gh pr view <number> --json commits,mergeable,mergeStateStatus
```

## Conflict Resolution

When merge conflicts occur:

### Obvious Conflicts

Resolve directly when the conflict is clearly one of:

- Formatting differences (whitespace, line endings)
- Simple additions that don't overlap semantically
- Deleted code that was also modified (usually keep the modification or deletion based on intent)
- Import statement ordering

### Non-Obvious Conflicts

For conflicts requiring analysis, delegate to specialized agents:

1. **Use Explore agent** to understand:
   - What each side of the conflict is trying to accomplish
   - The history of the conflicting changes
   - Related code that might inform the resolution

2. **Use Plan agent** to determine:
   - The correct resolution strategy
   - Whether both changes can coexist
   - If architectural decisions are needed

3. **Execute the resolution** - The executing agent owns the final resolution. Agent delegations are helpers, not decision-makers.

4. **Verify the resolution** - Run tests or builds to confirm the merge didn't break anything.

For detailed conflict resolution patterns, see `references/conflict-resolution.md`.

## Safety Rules

**Only modify the requested branch:**

- ONLY update the specific PR/branch that was requested
- Do NOT recursively update parent PRs, even if the base branch is itself a feature branch that's out of date
- If the base branch is out of date, merge it as-is into the feature branch - updating the base is a separate operation
- Example: If PR #123 (feature-a) is based on PR #100 (feature-b), and feature-b is behind main, only update feature-a with current state of feature-b

**Never rewrite history:**

- Never use `git push --force`
- If force is absolutely required, use `--force-with-lease` or `--force-if-includes`
- Prefer merge over rebase

**Preserve all changes:**

- Local commits must end up on remote
- Remote commits must be preserved
- Base branch changes must be incorporated

## CI/Remote Environment Usage

This skill works identically in CI and local environments:

- Use `git` directly for all operations
- Git identity configuration is outside this skill's scope
- The CI environment should configure `user.name` and `user.email` appropriately

## Error Handling

| Error                            | Resolution                                   |
| -------------------------------- | -------------------------------------------- |
| No PR found for branch           | Ask user for base branch, or create PR first |
| Merge conflicts                  | Follow conflict resolution workflow          |
| Push rejected (non-fast-forward) | Pull first, then push again                  |
| Authentication failure           | Ensure `gh` and `git` are authenticated      |

## Additional Resources

For detailed conflict resolution guidance, consult:

- **`references/conflict-resolution.md`** - Patterns for analyzing and resolving merge conflicts
