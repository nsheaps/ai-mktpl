# Code Quality Rules

Standards for writing and reviewing code.

## Git Workflow

### Clean Working Directory Before Starting Tasks

**CRITICAL:** Before starting any significant new task, check `git status` to ensure the working directory is clean.

If uncommitted changes exist:

1. **Ask the user** what to do with them:
   - Commit them first (if they're complete)
   - Stash them (if they're work-in-progress)
   - Discard them (if they're unwanted)
2. **Do NOT proceed** with new work until resolved

**Why this matters:**

- Isolates changes from the new task for easier review/revert
- Prevents mixing unrelated changes in commits
- Avoids confusion about what belongs to which task
- Deleted symlinks, untracked files, or staged changes indicate prior work that needs handling

**Example workflow:**

```bash
# FIRST: Check status
git status

# IF dirty, ask user before proceeding:
# "I see uncommitted changes (deleted symlinks, untracked spec file).
#  Should I commit these first, stash them, or discard them?"

# ONLY THEN: Start new work
```

### Preserving Git History

**NEVER rewrite pushed git history:**

- NEVER use `git commit --amend` on commits that have been pushed - create new commits instead
- NEVER use `git push --force` - if you must force push, use `--force-with-lease --force-if-includes`
- NEVER use `git rebase` to rewrite commits that already exist on the remote
- Always prefer adding to history over changing it
- When you make a mistake, fix it with a new commit rather than amending

**When rebase IS appropriate:**

- Rebasing local commits before pushing (to clean up history before it's shared)
- `git pull --rebase` to avoid merge commits when syncing with remote
- Rebasing a feature branch onto main before merging (if commits haven't been pushed yet)

**For automated agents in CI/remote environments:**
After committing changes, always push immediately. Don't ask - just push.

**For local/interactive assistants:**
Only commit and push when explicitly asked by the user. Local assistants should always defer to user preferences.

### Git Configuration Scope

When a user mentions git configuration issues or requests config changes, **always ask** whether the change should be:

1. **In-repo** (`git config` without `--global`) - Affects only this repository
2. **Global** (`git config --global`) - Affects all repositories for this user

**Why:** Global config changes require explicit permission approval and affect other projects. The user should consciously choose the scope.

**Example prompt:**

> "Should this git config change be made for this repository only, or globally for all your repositories?"

**Git command formatting (for permissions compatibility):**

- Prefer `git <cmd>` over `git -C <directory> <cmd>`
- The `-C` flag makes it harder to write permission approval patterns
- Only specify directory when your working directory has been reset and it's truly necessary
- When directory IS needed, prefer `cd <dir> && git <cmd>` over `git -C <dir> <cmd>`

```bash
# GOOD (when already in repo):
git rm -r .github/actions/old-action

# AVOID:
git -C /path/to/repo rm -r .github/actions/old-action

# ACCEPTABLE (when directory change is necessary):
cd /path/to/repo && git rm -r .github/actions/old-action
```

### Never Remove Git Lock Files

Sometimes a background process is using git when you want to use it. If you get a lock error, try again up to 3 times total.
If a lock still exists, DO NOT REMOVE IT.

**CRITICAL:** NEVER remove git lock files (`.git/**/index.lock`, `.git/**/HEAD.lock`, etc.) automatically.

When you encounter a git lock file error like:

```
fatal: Unable to create '/path/to/repo/.git/index.lock': File exists.
```

**Do NOT:**

- Run `rm -f .git/index.lock` or similar
- Automatically remove any `.lock` file in the `.git` directory
- Assume the lock is stale and can be safely removed

**Why this is dangerous:**

1. **Lock files exist for a reason** - Another git process may be actively running
2. **Removing them can cause data corruption** - Interrupting a git operation mid-write can corrupt the repository
3. **The user may have another terminal/IDE using git** - VSCode, GitKraken, or another process may hold the lock

**Instead, ALWAYS ask the user:**

> "I encountered a git lock file error. This usually means another git process is running. Could you:
>
> 1. Check if another git operation is in progress (another terminal, IDE, etc.)
> 2. If you're certain no other process is running, let me know and I can remove the lock file
> 3. Or run `rm .git/index.lock` yourself if you prefer"

**Only remove the lock after explicit user confirmation.**

## Task Completion

Your task is rarely done after making changes. Always:

1. Review the code
2. Compare against the original request
3. Ensure it satisfies the requirements
4. Make sure the code isn't overcomplicated
5. **Test your changes locally**

### Testing your changes

**CRITICAL:** Don't just make changes - ALWAYS test them to verify they work.

- Run the project's test/check commands (e.g., `just check`, `npm test`, `pytest`)
- For justfile changes: test each new/modified recipe
- For workflow changes: verify syntax and test locally where possible
- For scripts: execute them with test inputs
- If changes can't be fully tested locally, note what remains untested

Spot-checking a single command is NOT sufficient. Run the full validation suite.

You can commit before or after testing - the order doesn't matter. What matters is that you DO test.

### Local and remote validation

Most changes should be validated by CI when creating a PR or full validation on the default branch.

CRITICAL: CI workflows should be easily replicable locally using the same source-of-truth source code.
CRITICAL: Validation is considered a failure if CI fails, regardless of if it passes with local tooling. If CI is inaccessible, ask the user for help.
CRITICAL: Validation is also considered a failure if results locally do not match CI. CI is the source of truth, and must provide confidence that the changes will not introduce regressions.

## Package Management

When making a new package or finishing a task:

1. Ensure any added packages are actually needed
2. Remove unneeded packages before finishing
3. If working on a PR, check all changed package files (even if not your specific task)

## Error Handling

- When you get an error that something doesn't exist, don't assume it's missing
- The error may be due to passing the wrong path
- Double check WHY it says it's missing before creating anything new
- Research every error - don't assume you know the cause
- Confirm with research, understand WHY, then approach resolution

## Respecting File Modifications

When you encounter a file that has been modified since you last read it:

- **NEVER** blindly overwrite user changes with your planned changes
- **ALWAYS** review what changed and why
- Consider these options:
  1. Ask the user if they want to keep their modifications
  2. Incorporate their changes into your update
  3. Explain the conflict and ask how to proceed
- This applies even when the modification seems minor or was done by a linter
- The user's changes are intentional and should be respected
- When possible, lean on unit testing to validate integration of two change sets

## Safe File Deletion During Migrations

When migrating, refactoring, or cleaning up files:

- **NEVER delete files** until you've validated the new version works
- Instead, preserve the original by:
  1. Moving to a backup folder (e.g., `.backup/` or `_old/`)
  2. Renaming with `.bak` extension
  3. Commenting out code instead of deleting
- **ESPECIALLY critical** when working outside the current project (like `~/` files)
- Only delete the backup after confirming the new implementation works
- This prevents data loss of important configurations, scripts, or functions

**Prefer `git rm` over `rm -rf` for tracked files:**

- Use `git rm -r <path>` instead of `rm -rf <path>` for git-tracked files/directories
- `git rm` is safer: it only removes tracked files and stages the deletion
- `rm -rf` can accidentally delete untracked files, ignores git state, and requires separate `git add`
- This also typically gets auto-approved by permission systems since it's a git command

Example safe migration:

```bash
# BAD: rm ~/.zshrc.d/00_zshconfig.zsh
# GOOD: mv ~/.zshrc.d/00_zshconfig.zsh ~/.zshrc.d/00_zshconfig.zsh.bak

# For git-tracked files:
# BAD: rm -rf .github/actions/old-action
# GOOD: git rm -r .github/actions/old-action
```

## Parallelization

When possible, run Tasks in your Task list in parallel.
