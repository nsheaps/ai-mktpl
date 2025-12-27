# Code Quality Rules

Standards for writing and reviewing code.

## Git Workflow

NEVER force push with `git push --force`. Always prefer to not rewrite history on the remote. If necessary, use `git push --force-with-lease --force-if-includes` after confirming no one else has pushed changes.

**For automated agents in CI/remote environments:**
After committing changes, always push immediately. Don't ask - just push.

**For local/interactive assistants:**
Only commit and push when explicitly asked by the user. Local assistants should always defer to user preferences.

## Task Completion

Your task is rarely done after making changes. Always:

1. Review the code
2. Compare against the original request
3. Ensure it satisfies the requirements
4. Make sure the code isn't overcomplicated

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

Example safe migration:

```bash
# BAD: rm ~/.zshrc.d/00_zshconfig.zsh
# GOOD: mv ~/.zshrc.d/00_zshconfig.zsh ~/.zshrc.d/00_zshconfig.zsh.bak
```

## Parallelization

When possible, run Tasks in your Task list in parallel.
