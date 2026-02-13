# git-spice CLI Reference

Complete reference for all `gs` commands, flags, shorthands, and configuration options.

> Sources: [CLI Reference](https://abhinav.github.io/git-spice/cli/reference/), [Shorthands](https://abhinav.github.io/git-spice/cli/shorthand/), [Configuration](https://abhinav.github.io/git-spice/cli/config/)

---

## Command Structure

All commands follow: `gs <group> <action> [flags]`

Shorthands use initials: `gs branch create` -> `gs bc`, `gs stack submit` -> `gs ss`

---

## Navigation Commands

| Command | Description |
|---------|-------------|
| `gs up` | Check out the branch above current in the stack |
| `gs down` | Check out the branch below current in the stack |
| `gs top` | Check out the topmost branch in the stack |
| `gs bottom` | Check out the bottommost branch (above trunk) |
| `gs trunk` | Check out the trunk branch |

All navigation commands support `-n` / `--dry-run` to print target branch name without checking out.

---

## gs repo (Repository Commands)

### gs repo init (gs ri)

Initialize git-spice for a repository. Sets trunk branch and remote.

**Flags:**
- `--trunk <branch>`: Specify trunk branch (default: prompted)
- `--remote <remote>`: Specify remote (default: prompted)

### gs repo sync (gs rs)

Pull latest changes from remote, delete merged branches, prepare for restacking.

- Skips branches checked out in other worktrees
- Detects squash-merged PRs and cleans up

---

## gs branch (Branch Commands)

### gs branch create (gs bc)

Create a new branch stacked on current branch.

**Flags:**
- `--insert` / `-i`: Insert between current branch and its upstack
- `--all` / `-a`: Commit all tracked changes (like `git commit -a`)
- `--message` / `-m`: Commit message for staged changes
- `--no-commit`: Create branch without committing staged changes

### gs branch checkout (gs bco)

Check out a tracked branch. Without arguments, shows fuzzy-searchable tree.

**Flags:**
- `-u` / `--untracked`: Also show untracked branches in the prompt

### gs branch delete (gs bd)

Delete one or more branches. Rebases upstack branches onto next available downstack.

**Flags:**
- `--force` / `-f`: Force delete even if branch has unmerged changes

### gs branch rename (gs brn)

Rename a tracked branch. `gs brn [old] [new]`

### gs branch track (gs bt)

Track an existing (untracked) branch with git-spice.

### gs branch untrack (gs but)

Stop tracking a branch without deleting it.

### gs branch onto (gs bo)

Move only the current branch to a different base. Upstack stays on original base.

**Flags:**
- `--branch` / `-b`: Target a different branch (not the current one)

### gs branch restack (gs br)

Restack a single branch on top of its base.

### gs branch split (gs bsp)

Interactively split a branch at commit boundaries into multiple branches. Prompts for split points and new branch names.

### gs branch edit (gs be)

Interactive rebase of the current branch. Allows squash, fixup, reorder commits.

### gs branch submit (gs bs)

Submit (create/update) a PR for the current branch only.

### gs branch up / gs branch down

Navigate to the branch above/below current in the stack. Also available as top-level `gs up` / `gs down`.

---

## gs commit (Commit Commands)

### gs commit create (gs cc)

Commit staged changes and restack all upstack branches automatically. Equivalent to `git commit` + `gs upstack restack`.

**Flags:**
- `-a` / `--all`: Stage all tracked changes before committing
- `-m` / `--message`: Commit message

### gs commit amend (gs ca)

Amend the last commit and restack all upstack branches automatically.

### gs commit split (gs csp)

Interactively split the last commit into two commits and restack upstack.

---

## gs stack (Stack Commands)

### gs stack submit (gs ss)

Submit all branches in the current stack as PRs.

### gs stack restack (gs sr)

Restack all branches in the current stack. Rebases each branch onto its base.

### gs stack edit (gs se)

Edit the entire stack interactively. Reorder, move branches between bases.

---

## gs upstack (Upstack Commands)

### gs upstack submit (gs uss)

Submit the current branch and all upstack branches as PRs.

### gs upstack restack (gs ur)

Restack all branches upstack from current.

### gs upstack onto (gs uo)

Move the current branch AND its entire upstack to a new base. Unlike `gs branch onto` which moves only the current branch.

---

## gs downstack (Downstack Commands)

### gs downstack submit (gs dss)

Submit the current branch and all downstack branches as PRs.

### gs downstack edit (gs dse)

Edit the downstack interactively.

### gs downstack track (gs dst)

Traverse commit graph downward, tracking untracked branches along the way. Useful for onboarding existing branch chains.

---

## gs log (Log/Visualization Commands)

### gs log short (gs ls)

Short view of the stack showing branch names, relationships, and CR status.

**Flags:**
- `--all` / `-a`: Show all stacks, not just the current one
- `--json`: Output as JSON

### gs log long (gs ll)

Detailed view including individual commits for each branch.

**Flags:**
- `--all` / `-a`: Show all stacks
- `--json`: Output as JSON

---

## gs rebase (Rebase Commands)

### gs rebase continue (gs rbc)

Continue a git-spice operation interrupted by a rebase conflict. Run after resolving conflicts and staging files.

### gs rebase abort (gs rba)

Abort an ongoing git-spice rebase operation.

---

## gs auth (Authentication Commands)

### gs auth login

Log in to GitHub or GitLab. Prompts for authentication method:
- **OAuth**: Web-based device flow
- **GitHub App**: Repository-scoped access (GitHub only)
- **PAT**: Personal Access Token (best for orgs without admin approval, or self-hosted GitLab)

Tokens stored in system keychain (macOS) or Secret Service (Linux), with plain-text fallback.

### gs auth status

Check current authentication status.

### gs auth logout

Log out and remove stored credentials.

---

## gs shell (Shell Commands)

### gs shell completion [shell]

Generate shell completion script. Supported shells: bash, zsh, fish.

```bash
eval "$(gs shell completion bash)"   # Bash
eval "$(gs shell completion zsh)"    # Zsh
eval "$(gs shell completion fish)"   # Fish
eval "$(gs shell completion)"        # Auto-detect
```

---

## Submit Command Flags

These flags apply to all submit commands (`gs branch submit`, `gs stack submit`, `gs upstack submit`, `gs downstack submit`):

| Flag | Description |
|------|-------------|
| `--fill` | Populate title and body from commit messages |
| `--draft` / `--no-draft` | Mark CR as draft or not |
| `--dry-run` | Print what would be submitted without submitting |
| `--no-verify` | Bypass pre-push hooks |
| `--update-only` | Only update existing CRs, don't create new ones |
| `--nav-comment` | Control navigation comment behavior |
| `--web` / `-w` | Open browser with submitted CR |
| `--reviewer` / `-r` | Assign reviewers |
| `--assignee` / `-a` | Assign assignees |
| `--label` / `-l` | Add labels |
| `--template` | Use a specific PR template |

---

## Complete Shorthand Reference

| Shorthand | Full Command | Category |
|-----------|-------------|----------|
| `gs ri` | `gs repo init` | Repository |
| `gs rs` | `gs repo sync` | Repository |
| `gs bc` | `gs branch create` | Branch |
| `gs bco` | `gs branch checkout` | Branch |
| `gs bd` | `gs branch delete` | Branch |
| `gs brn` | `gs branch rename` | Branch |
| `gs bt` | `gs branch track` | Branch |
| `gs but` | `gs branch untrack` | Branch |
| `gs bo` | `gs branch onto` | Branch |
| `gs br` | `gs branch restack` | Branch |
| `gs bsp` | `gs branch split` | Branch |
| `gs be` | `gs branch edit` | Branch |
| `gs bs` | `gs branch submit` | Branch |
| `gs cc` | `gs commit create` | Commit |
| `gs ca` | `gs commit amend` | Commit |
| `gs csp` | `gs commit split` | Commit |
| `gs ss` | `gs stack submit` | Stack |
| `gs sr` | `gs stack restack` | Stack |
| `gs se` | `gs stack edit` | Stack |
| `gs uss` | `gs upstack submit` | Upstack |
| `gs ur` | `gs upstack restack` | Upstack |
| `gs uo` | `gs upstack onto` | Upstack |
| `gs dss` | `gs downstack submit` | Downstack |
| `gs dse` | `gs downstack edit` | Downstack |
| `gs dst` | `gs downstack track` | Downstack |
| `gs ls` | `gs log short` | Log |
| `gs ll` | `gs log long` | Log |
| `gs rbc` | `gs rebase continue` | Rebase |
| `gs rba` | `gs rebase abort` | Rebase |

---

## Configuration Reference

All configuration uses `git config`. Supports `--global`, `--local`, `--worktree`, and `--system` scopes.

### Branch Configuration

| Key | Description | Default |
|-----|-------------|---------|
| `spice.branchCreate.prefix` | Prefix for branch names created with `gs bc` | (none) |
| `spice.branchCreate.generatedBranchNameLimit` | Max length of auto-generated branch names | (unlimited) |
| `spice.branchCheckout.showUntracked` | Show untracked branches in `gs bco` | `false` |
| `spice.branchCheckout.trackUntrackedPrompt` | Prompt to track untracked branches during checkout | `true` |

### Submit Configuration

| Key | Description | Default |
|-----|-------------|---------|
| `spice.submit.publish` | Create CRs on forge (false = push only) | `true` |
| `spice.submit.draft` | Default draft status for new CRs | `false` |
| `spice.submit.web` | Open browser after submitting | `false` |
| `spice.submit.updateOnly` | Default to `--update-only` | `false` |
| `spice.submit.reviewers` | Default reviewers (comma-separated) | (none) |
| `spice.submit.reviewers.addWhen` | When to add reviewers | `always` |
| `spice.submit.assignees` | Default assignees | (none) |
| `spice.submit.label` | Default labels | (none) |
| `spice.submit.template` | Default PR template | (none) |
| `spice.submit.navigationComment` | Navigation comment behavior | `true` |
| `spice.submit.navigationComment.downstack` | Which downstack CRs in nav comments | (all) |
| `spice.submit.navigationCommentStyle.marker` | Marker style for nav comments | (default) |
| `spice.submit.navigationCommentSync` | Sync nav comments on update | `true` |
| `spice.submit.listTemplatesTimeout` | Timeout for listing PR templates | (default) |
| `spice.submit.noVerify` | Default to `--no-verify` | `false` |

### Log Configuration

| Key | Description | Default |
|-----|-------------|---------|
| `spice.log.all` | Default to `--all` for `gs ls` and `gs ll` | `false` |
| `spice.log.crFormat` | Format for CR information in log output | (default) |
| `spice.log.crStatus` | Show CR status in log | `true` |
| `spice.log.pushStatusFormat` | Push status display format | (default) |
| `spice.logLong.crFormat` | CR format for `gs ll` | (inherits) |
| `spice.logShort.crFormat` | CR format for `gs ls` | (inherits) |

### Navigation Configuration

| Key | Description | Default |
|-----|-------------|---------|
| `spice.checkout.verbose` | Print message when switching branches | `false` |

### Forge Configuration

| Key | Description | Default |
|-----|-------------|---------|
| `spice.forge.github.url` | URL for GitHub Enterprise | (github.com) |
| `spice.forge.gitlab.apiUrl` | API URL for self-hosted GitLab | (gitlab.com) |

---

## Advanced Workflows

### Inserting a Branch Mid-Stack

```bash
# On feature-a (which has feature-b stacked on top)
gs branch create --insert hotfix
# Creates: trunk → feature-a → hotfix → feature-b
```

### Reorganizing Branches Between Stacks

```bash
# Move current branch + upstack to a different base
gs upstack onto other-branch

# Move only current branch (upstack stays)
gs branch onto other-branch
```

### Splitting a Large Branch

```bash
# Split at commit boundaries
gs branch split
# Prompts for split points and new branch names

# Or split the last commit into two
gs commit split
```

### Editing Commits Within a Branch

```bash
# Interactive rebase within current branch
gs branch edit
# Allows squash, fixup, reorder, drop
```

### Bulk Tracking Existing Branches

```bash
# Track a chain of branches downward from current
gs downstack track
# Walks the commit graph down to trunk, tracking along the way
```

### Machine-Readable Output

```bash
gs ls --json    # JSON format stack view
gs ll --json    # JSON format detailed stack view
```

---

## Comparison with Alternatives

| Tool | Forges | Local-first | Shorthands | Cloud Required |
|------|--------|-------------|------------|----------------|
| git-spice (gs) | GitHub, GitLab | Yes | Yes | No |
| Graphite (gt) | GitHub | No | Yes | Yes |
| ghstack | GitHub | Yes | No | No |
| spr | GitHub | Yes | No | No |

---

## Limitations

- **Squash-merge reconciliation**: After squash-merge, all upstack branches need restacking (commit hashes change)
- **Git 2.38+ required**: Older versions may have partial functionality
- **Interactive prompts**: Commands like `gs bco`, `gs bsp`, `gs se`, `gs csp` use interactive prompts that do not work in non-TTY environments
- **Single remote**: git-spice works with one remote per repository
