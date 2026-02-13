---
description: Synchronize a branch with its base and push all changes
argument-hint: [pr-number|url|branch|directory]
allowed-tools: Bash, Read, Grep, Glob, Task
---

Synchronize the target branch with its remote counterpart and ensure it's up-to-date with its base branch.

**Load the update-branch skill** from scm-utils for the complete workflow.

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

PR info for current branch:
!`gh pr view --json baseRefName,headRefName,number,title,state 2>/dev/null || echo "(no PR found or gh not authenticated)"`

## Execute the Workflow

1. Fetch all remotes
2. Get base branch from PR metadata (never assume)
3. Merge base branch into feature branch
4. Pull remote feature branch changes
5. Push to remote
6. Verify the PR is updated

## Safety Reminders

- ONLY update the requested branch - do NOT recursively update parent PRs
- Never use `--force` - only `--force-with-lease` or `--force-if-includes` if absolutely necessary
- Prefer merge over rebase to preserve history

## Conflict Handling

If merge conflicts occur:

- For obvious conflicts (formatting, simple additions): resolve directly
- For non-obvious conflicts: use Explore agent to understand both sides, Plan agent to determine resolution
- The executing agent owns the final resolution - delegations are helpers

## Completion Messaging

When reporting completion, use clear language that doesn't imply the PR was merged:

**Don't say:** "PR #123 is now merged with main" (implies PR merged INTO main)

**Do say:** "Branch updated: merged base branch (main) into feature branch, synced local and remote"
