---
name: git-spice
description: >
  This skill should be used when the user asks to "create a stacked branch",
  "stack a branch", "submit stacked PRs", "restack branches", "use git-spice",
  "use gs", "manage stacked PRs", "sync stacked branches", "split a branch",
  "navigate branch stack", "submit stack", "restack", or mentions git-spice,
  stacked branches, stacked PRs, or the gs CLI tool. Provides comprehensive
  guidance for managing stacked Git branches with git-spice.
---

# git-spice (gs) - Stacked Branch Management

git-spice is a CLI tool (`gs`) for managing stacked Git branches. It automates tracking parent-child relationships between branches, rebasing dependent branches when a base changes, and creating/updating PRs across entire stacks with a single command.

## Prerequisites

- **Git 2.38+** installed
- **git-spice** installed (`brew install git-spice` or `go install go.abhg.dev/gs@latest`)
- Repository initialized with `gs repo init`
- Authenticated with `gs auth login` (for PR operations)

Check installation: `gs --version`. Check auth: `gs auth status`.

## Key Concepts

**Trunk**: The main/default branch (e.g., `main`). Root of all stacks.

**Stack**: A chain of branches where each builds on the one below:

```
trunk (main) → feature-a → feature-b → feature-c
```

**Upstack/Downstack**: Upstack = branches above current. Downstack = branches below current (excluding trunk).

**Tracked branches**: git-spice only manages branches it tracks. Branches created with `gs branch create` are auto-tracked. Track existing branches with `gs branch track`.

**Restacking**: When a branch changes, all upstack branches need rebasing. `gs commit create` and `gs commit amend` do this automatically.

**Forge**: The remote hosting platform (GitHub or GitLab). PRs/MRs are called "Change Requests" (CRs).

## Core Workflow

### 1. Initialize and Authenticate

```bash
gs repo init --trunk main --remote origin
gs auth login
```

### 2. Create a Stack

```bash
gs branch create feature-part-1       # gs bc
# ... make changes, stage them ...
gs commit create -m "Add part 1"       # gs cc

gs branch create feature-part-2       # gs bc
# ... make changes, stage them ...
gs commit create -m "Add part 2"       # gs cc
```

### 3. View and Submit

```bash
gs log short                           # gs ls (view stack)
gs stack submit --fill                 # gs ss (submit all as PRs)
```

### 4. Address Review Feedback

```bash
gs branch checkout feature-part-1     # gs bco (navigate to branch)
# ... make fixes, stage them ...
gs commit create -m "Fix feedback"     # gs cc (auto-restacks upstack)
gs stack submit                        # gs ss (update all PRs)
```

### 5. Sync After Merges

```bash
gs repo sync                           # gs rs (pull + delete merged)
gs stack restack                       # gs sr (rebase remaining)
gs stack submit                        # gs ss (update PRs)
```

## Essential Commands Quick Reference

| Action                  | Command                     | Shorthand |
| ----------------------- | --------------------------- | --------- |
| Create stacked branch   | `gs branch create <name>`   | `gs bc`   |
| Checkout (fuzzy search) | `gs branch checkout`        | `gs bco`  |
| Commit + auto-restack   | `gs commit create -m "msg"` | `gs cc`   |
| Amend + auto-restack    | `gs commit amend`           | `gs ca`   |
| View stack (short)      | `gs log short`              | `gs ls`   |
| View stack (detailed)   | `gs log long`               | `gs ll`   |
| Submit all PRs          | `gs stack submit`           | `gs ss`   |
| Restack all             | `gs stack restack`          | `gs sr`   |
| Sync with remote        | `gs repo sync`              | `gs rs`   |
| Navigate up/down        | `gs up` / `gs down`         |           |
| Move branch to new base | `gs branch onto <base>`     | `gs bo`   |
| Move branch + upstack   | `gs upstack onto <base>`    | `gs uo`   |
| Delete branch           | `gs branch delete`          | `gs bd`   |
| Split branch            | `gs branch split`           | `gs bsp`  |
| Split last commit       | `gs commit split`           | `gs csp`  |
| Edit branch (rebase)    | `gs branch edit`            | `gs be`   |
| Track existing branch   | `gs branch track`           | `gs bt`   |
| Continue after conflict | `gs rebase continue`        | `gs rbc`  |
| Abort rebase            | `gs rebase abort`           | `gs rba`  |

For the complete CLI reference with all flags and options, see `references/cli-reference.md`.

## Important: Use gs Commands Over git Commands

When git-spice is initialized in a repository, prefer `gs` commands over raw `git` equivalents:

- **Use `gs commit create`** instead of `git commit` -- it auto-restacks upstack branches
- **Use `gs commit amend`** instead of `git commit --amend` -- it auto-restacks upstack branches
- **Use `gs branch create`** instead of `git checkout -b` -- it tracks the branch in the stack
- **Use `gs branch delete`** instead of `git branch -d` -- it rebases upstack onto the next downstack

> **CRITICAL: ALWAYS use `gs stack submit` or `gs branch submit` to push changes. NEVER use `git push`.**
>
> `git push` bypasses git-spice's tracking and **breaks PR linkage** -- branches pushed with `git push` will not have their PRs tracked by git-spice. This means git-spice won't know about the PR, won't update it on subsequent submits, and stack-wide operations like `gs stack submit` will skip the unlinked branch.
>
> **If a branch was accidentally pushed with `git push`**, run `gs stack submit` or `gs branch submit` to fix the linkage and re-associate the branch with its PR.

Never use `git rebase`, `git cherry-pick`, or `git merge` on tracked branches -- these bypass git-spice's dependency tracking and leave the stack in an inconsistent state requiring manual recovery. If the stack gets out of sync, run `gs stack restack` to reconcile.

## Submit Flags

Common flags for all submit commands (`gs ss`, `gs bs`, `gs uss`, `gs dss`):

| Flag                     | Purpose                                     |
| ------------------------ | ------------------------------------------- |
| `--fill`                 | Populate PR title/body from commit messages |
| `--draft` / `--no-draft` | Set draft status                            |
| `--reviewer` / `-r`      | Assign reviewers                            |
| `--assignee` / `-a`      | Assign assignees                            |
| `--label` / `-l`         | Add labels                                  |
| `--web` / `-w`           | Open browser after submit                   |
| `--dry-run`              | Preview without submitting                  |

## Handling Conflicts

When restacking causes conflicts:

1. Resolve the conflict in the affected files
2. Stage the resolved files with `git add`
3. Run `gs rebase continue` (or `gs rbc`)
4. To abort instead: `gs rebase abort` (or `gs rba`)

## Squash-Merge Reconciliation

When a PR is squash-merged on GitHub/GitLab, commit hashes change and upstack branches become stale:

```bash
gs repo sync        # Detects merged branches, deletes them
gs stack restack    # Rebases remaining branches onto updated trunk
gs stack submit     # Updates remaining PRs
```

## Configuration

git-spice uses `git config` for settings. Common useful settings:

```bash
# Prefix branch names (e.g., with username)
git config spice.branchCreate.prefix "myname/"

# Always create PRs as drafts
git config spice.submit.draft true

# Set default reviewers
git config spice.submit.reviewers "teammate1,teammate2"

# Show all stacks by default in gs ls
git config spice.log.all true
```

For the complete configuration reference, see `references/cli-reference.md`.

## Worktree Considerations

In multi-agent or multi-member workflows, worktrees are essential for parallel branch work without disrupting each other's checkouts. Incorrect branch naming in worktrees can silently bypass git's checkout protection, leading to conflicting pushes and lost work. For full guidance on branch naming rules and PR checkout procedures, recall the `scm-utils` plugin's `git-worktree` skill.

git-spice supports Git worktrees:

- `gs repo sync` skips branches checked out in other worktrees
- `gs branch delete` handles cross-worktree branches gracefully
- Restacking skips branches checked out in other worktrees
- Use `--worktree` config scope for worktree-specific settings

## Claude Code Integration Notes

When acting as an AI assistant using git-spice:

- **CRITICAL: ALWAYS use `gs stack submit` (`gs ss`) or `gs branch submit` (`gs bs`) to push changes. NEVER use `git push`.** Using `git push` breaks git-spice's PR tracking -- the branch will not be linked to its PR and will be skipped by future stack-wide submit operations. If this happens accidentally, run `gs stack submit` or `gs branch submit` to repair the linkage.
- **Never run interactive gs commands** (`gs bco`, `gs branch split`, `gs stack edit`, `gs commit split`) without user confirmation -- these require TTY interaction
- **Prefer shorthand commands** for efficiency (`gs cc`, `gs ss`, `gs rs`)
- **Always check stack state** with `gs ls` before and after operations
- **Use `--fill` on first submit** to auto-populate PR descriptions
- **Run `gs repo sync` before starting new work** to ensure a clean state
- **After submitting**, share the PR URLs with the user
- **If `gs` is not installed**, suggest installation: `brew install git-spice`
- **If repo is not initialized**, run `gs repo init` first

## Checking for Remote Changes Before Pushing

`gs stack submit` and `gs branch submit` force-push branches. This **overwrites remote changes** made by CI auto-fixes, collaborators, GitHub bots, or other agents. Always check for remote-only commits before submitting.

### Before Running `gs stack submit` or `gs branch submit`

```bash
git fetch origin
git log HEAD..origin/<branch-name> --oneline
```

If there are remote-only commits, incorporate them before submitting.

### Incorporating Remote Changes

```bash
git pull --rebase origin <branch-name>
```

This rebases local commits on top of remote changes. After pulling on a stacked branch, propagate changes to upstack branches before submitting:

```bash
gs stack restack    # gs sr
gs stack submit     # gs ss
```

### When to Expect Remote Changes

Always fetch first when working on a branch that others may have modified:

- **Another agent** pushed a fix to the same branch
- **CI auto-formatted or auto-fixed** code (e.g., linting, formatting hooks)
- **A collaborator** pushed directly to the branch
- **GitHub bots** made commits (e.g., dependency updates, changelog generation)

### Quick Pre-Submit Checklist

1. `git fetch origin`
2. `git log HEAD..origin/<branch-name> --oneline` -- any remote-only commits?
3. If yes: `git pull --rebase origin <branch-name>`
4. If on a stacked branch: `gs stack restack`
5. Proceed with `gs stack submit` or `gs branch submit`

## Using Worktrees for Parallel Branch Work

Git worktrees allow checking out multiple branches simultaneously in
separate directories. This is especially useful for agents working on
multiple PRs in parallel without disrupting the main checkout.

### Creating a Worktree

```bash
# Create a worktree for an existing branch
git worktree add /path/to/repo.worktrees/<short-name> <branch-name>

# Convention: use <repo>.worktrees/<description> as the path
# Example:
git worktree add /Users/me/src/org/repo.worktrees/fix-auth nate/fix-auth-bug
```

### Working in a Worktree

- Run all commands from the worktree directory (cd there first)
- `gs` commands work normally — the worktree shares the same git-spice state
- `pnpm install` may be needed if dependencies differ from main checkout
- Type checks and linting work as normal: `cd packages/<pkg> && pnpm lint:tsc`

### Committing and Pushing from a Worktree

```bash
cd /path/to/repo.worktrees/<short-name>
# Stage and commit with git-spice
gs cc -m "fix: description of change"
# Push and update PR
gs ss
```

### Cleaning Up Worktrees

**CRITICAL:** Always clean up worktrees when done. A branch checked out
in a worktree cannot be checked out elsewhere (git prevents it), which
blocks other agents and the user from working on that branch.

```bash
# From the main repo (NOT from inside the worktree)
cd /path/to/main/repo
git worktree remove /path/to/repo.worktrees/<short-name>
```

If the worktree has uncommitted changes, either commit them first or
use `--force` (only if changes should be discarded).

### Worktree Detection in gs-stack-status

The `gs-stack-status.sh` script automatically detects branches checked
out in other worktrees and displays them with a bold magenta `＋`
indicator before the branch name. This helps identify which branches
are actively being worked on in parallel.

### When to Use Worktrees

| Scenario                                         | Approach                      |
| ------------------------------------------------ | ----------------------------- |
| Agent fixing a PR while user works on main       | Worktree for the agent        |
| Multiple agents fixing different PRs in parallel | One worktree per agent        |
| Quick one-off fix on a different branch          | Worktree, fix, cleanup        |
| Long-running work on a feature branch            | Worktree (or dedicated clone) |

### Anti-Patterns

- **Don't leave worktrees around** — they lock branches and confuse `gs ls`
- **Don't use the main checkout for agent work** if the user is active
- **Don't forget `pnpm install`** — worktrees share `node_modules` via
  symlinks but lock files may differ across branches

## Post-Task Cleanup: Closed/Merged PRs

After completing branch navigation or manipulation tasks (e.g., `gs bco`, `gs bo`, `gs uo`, `gs ls`, `gs sr`), check if any branches in the stack have closed or merged PRs. If so, prompt the user with `AskUserQuestion` offering these cleanup options:

1. **Untrack only** (`gs branch untrack <name>`) — stop tracking the branch but keep it locally
2. **Delete branch** (`gs branch delete <name>`) — untrack and delete the local branch; git-spice rebases upstack branches onto the deleted branch's parent
3. **Full sync** (`gs repo sync`) — detect all merged branches, delete them, and restack
4. **Skip** — leave as-is for now

### When Each Option Is Appropriate

| Option    | When to suggest                                                                 |
| --------- | ------------------------------------------------------------------------------- |
| Untrack   | PR was closed (not merged) and the user may want the local branch for reference |
| Delete    | User is done with the branch entirely                                           |
| Full sync | Multiple PRs have been merged and the user wants a clean slate                  |
| Skip      | User is in the middle of other work and doesn't want to disrupt flow            |

### Detection

Use `gs ls` output combined with `gh pr view <branch> --json state` (or the `gs-stack-status.sh` script with `--include-closed`) to identify branches whose PRs are closed or merged. Only prompt when at least one such branch is found.

**Note:** `gs-stack-status.sh` hides closed/merged PRs by default. Use `--include-closed` to see them — merged PRs render in green text, closed PRs render in red text, both with a ⛔️ prefix. When you see closed/merged PRs in the output, proactively suggest untracking them using the options above.

## Stack Status Overview

The plugin includes a script at `scripts/gs-stack-status.sh` that produces an annotated stack tree combining `gs ls --all` output with GitHub PR metadata.

### When to Use

- **Before starting work** to see which branches need attention (failed CI, pending review)
- **After submitting a stack** to verify all PRs have the expected review/CI state
- **During standup or pairing** to give a quick visual overview of all open stack work
- **When the user asks** for a summary of their stack, PR statuses, or CI health

### How to Run

```bash
# From any git-spice initialized repo
/path/to/plugins/git-spice/scripts/gs-stack-status.sh
```

The script requires `gs`, `gh`, and `jq` in PATH.

### Reading the Output

Each branch line is annotated with two emoji indicators and the PR title:

| Position     | Meaning       | Values                                                                                                      |
| ------------ | ------------- | ----------------------------------------------------------------------------------------------------------- |
| First emoji  | Review status | `🟢` approved, `🔴` changes requested, `🟡` unreviewed, `⚪` draft, `🔘` draft+approved                     |
| Second emoji | CI status     | `🟢` passing, `🔴` required failed, `🟡` running, `🟠` running+failures, `🟣` optional failures, `⚪` no CI |

Additional indicators:

- `＋` (bold magenta) before branch name = branch is checked out in another worktree
- `⛔️` prefix = closed/merged PR (only visible with `--include-closed`)
- Current branch is highlighted in bold yellow
- Merged PRs render in green text
- Closed PRs render in red text

The PR URL appears on the line below each branch (interactive mode). Branches without PRs (trunk) are shown as-is.

### Key Flags

| Flag                 | Effect                                            |
| -------------------- | ------------------------------------------------- |
| `--include-closed`   | Show closed/merged PRs (hidden by default)        |
| `--output osc8`      | Clickable hyperlinks (iTerm2, Kitty)              |
| `--output markdown`  | Markdown format (for Slack, GitHub comments)      |
| `--watch [SECS]`     | Auto-refresh in alternate screen buffer           |
| `--only-required-ci` | CI status reflects only required checks (default) |
| `--reviewed`         | Only show PRs that have been reviewed/approved    |
| `--failing-ci`       | Only show PRs where CI is failing                 |

## Additional Resources

### Reference Files

For detailed command flags, configuration options, and advanced workflows:

- **`references/cli-reference.md`** - Complete CLI reference with all commands, flags, shorthands, configuration keys, and advanced workflow examples
- **`references/worktrees-and-agents.md`** - Guide for using git-spice with Git worktrees in multi-agent workflows, covering setup, parallel branch development, coordination patterns, and best practices
- **`references/pr-status-and-stack-views.md`** - How to list PRs, get review/CI status, and combine `gs ls` with `gh pr view` for rich stack views
- **`references/tracking-external-branches.md`** - How to safely stack your branches on top of someone else's PR branch without accidentally pushing to or modifying their branch

### External Documentation

- [git-spice Official Docs](https://abhinav.github.io/git-spice/)
- [CLI Reference](https://abhinav.github.io/git-spice/cli/reference/)
- [Configuration](https://abhinav.github.io/git-spice/cli/config/)
- [GitHub Repository](https://github.com/abhinav/git-spice)
