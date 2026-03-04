# SCM Strategy: Stacked Changes with git-spice

Every generated prompt must include a stacked changes workflow using git-spice.
The agent produces small, logical, independently reviewable changes — not monolithic commits.

---

## Why Stacked Changes

Monolithic commits are hard to review, hard to revert, and hide bugs. Stacked changes:

- Each change does ONE thing (add an interface, implement a function, wire up a route)
- Reviewers can understand and approve each change independently
- If something breaks, you revert one small change, not an entire feature
- The agent can get faster feedback loops by submitting partial work for review
- git-spice automates the rebasing/dependency management that makes this practical

---

## git-spice Setup

The generated session-start script must install and initialize git-spice:

```bash
# Install git-spice (if not already present)
if ! command -v gs &>/dev/null; then
  echo "[git-spice] Installing..."
  go install go.abhg.dev/git-spice@latest 2>/dev/null || \
    brew install git-spice 2>/dev/null || \
    echo "[git-spice] Could not auto-install. Install manually: https://abhinav.github.io/git-spice/"
fi

# Initialize git-spice in the repo (idempotent)
if command -v gs &>/dev/null; then
  gs repo init 2>/dev/null || true
fi
```

Additionally, the `scm-utils` and `git-spice` plugins from `nsheaps/ai-mktpl` provide
the agent with knowledge of how to use git-spice correctly. These plugins MUST be installed.

---

## Stacked Change Workflow

### Per-Task Flow

Each task produces a stacked branch:

```bash
# Starting from main (or the current stack top)
gs branch create T0.3-storage-interface

# Do work, make atomic commits
git add -A && git commit -m "feat(core): define StorageBackend interface [T0.3]"

# If the task has natural sub-parts, commit each separately:
git add -A && git commit -m "feat(core): implement BrowserFsBackend [T0.3]"
git add -A && git commit -m "test(core): unit tests for BrowserFsBackend [T0.3]"

# Submit for review (creates/updates PR)
gs branch submit --fill
```

### When Tasks Depend on Each Other

```bash
# Task T1.1 creates storage interface
gs branch create T1.1-storage-interface
# ... implement ...
gs branch submit --fill

# Task T1.2 builds on T1.1
gs branch create T1.2-git-backend   # stacks on T1.1
# ... implement ...
gs branch submit --fill

# Task T1.3 is independent of T1.2 but needs T1.1
gs branch checkout T1.1-storage-interface
gs branch create T1.3-parser        # stacks on T1.1, parallel to T1.2
# ... implement ...
gs branch submit --fill
```

### Handling Review Feedback

```bash
# Reviewer requests changes on T1.1
gs branch checkout T1.1-storage-interface
# Make fixes
git add -A && git commit -m "fix(core): address review feedback [T1.1]"

# Restack dependent branches
gs upstack restack

# Re-submit the entire stack
gs stack submit
```

### Merging After Approval

```bash
# After T1.1 is approved and merged to main
gs repo sync          # Pulls main, detects merged branches
gs repo restack       # Restacks everything on new main
gs stack submit       # Updates remaining PRs
```

---

## SCM Workflow Variants

The generated prompt should use ONE of these variants based on the project's needs:

### Variant A: Solo Developer (Stacked on Main)

For solo projects or when the user is the only developer:

```
main ← T0.1 ← T0.2 ← T0.3 ...
```

- Agent creates stacked branches from main
- Each task is a branch with a PR
- PRs are auto-merged after review passes (agent reviews its own PRs via plugins)
- After merge, `gs repo sync` cleans up

This is the **default** for generated prompts unless the user specifies otherwise.

### Variant B: Team with PR Review

For team projects where humans review PRs:

```
main ← T0.1 ← T0.2 (waits for T0.1 merge) ← T0.3 ...
```

- Agent creates stacked branches
- Agent submits PRs via `gs stack submit`
- Humans review and merge
- Agent runs `gs repo sync` + `gs repo restack` at session start
- Agent continues from the top of the merged stack

### Variant C: Direct-to-Main (No PRs)

For rapid prototyping or when the user explicitly wants no PR workflow:

```
main: commit1 → commit2 → commit3 ...
```

- Agent commits directly to main
- Each task is one or more atomic commits
- No stacked branches, no PRs
- Reviews still happen via sub-agents and plugins, just not via GitHub PRs
- git-spice is still installed for its utilities but stacking is not used

Include this variant only if the user explicitly requests it.

---

## Commit Message Convention

Every generated prompt must enforce this convention:

```
<type>(<scope>): <description> [T<X>.<Y>]

Types: feat, fix, test, docs, refactor, chore, ci, style, perf
Scope: package or module name (core, ui, web, cli, etc.)
Task: reference to the task in TASKS.md
```

Examples:
```
feat(core): implement StorageBackend interface [T1.1]
test(core): unit tests for BrowserFsBackend [T1.1]
fix(ui): resolve keyboard navigation in block editor [T2.3]
docs(web): add onboarding guide with screenshots [T3.1]
refactor(core): extract parser into separate module [T1.3]
chore: update dependencies via renovate [T0.2]
```

---

## Embedding in the Generated Prompt

### In CLAUDE.md

```markdown
## SCM Workflow

This project uses git-spice for stacked changes. The scm-utils and git-spice plugins
from nsheaps/ai-mktpl are installed and provide detailed guidance.

**Per-task workflow:**
1. `gs branch create T<X>.<Y>-<short-description>`
2. Make atomic commits with conventional commit messages
3. Run reviews (sub-agent + plugin review)
4. `gs branch submit --fill` to create/update PR
5. After approval: `gs repo sync` → `gs repo restack` → continue

**Commit convention:** `<type>(<scope>): <description> [T<X>.<Y>]`

**Key commands:**
- `gs branch create <name>` — create a stacked branch
- `gs upstack restack` — rebase dependent branches after changes
- `gs stack submit` — submit all branches in stack as PRs
- `gs repo sync` — pull main, delete merged branches
- `gs log short` — view current stack
```

### In Session-Start Script

```bash
# ---- SCM Setup ----
# Sync with remote and restack
if command -v gs &>/dev/null; then
  gs repo sync 2>/dev/null || true
  gs repo restack 2>/dev/null || true
  echo "[git-spice] Stack synced and restacked"
  gs log short 2>/dev/null || true
fi
```

### In /continue Command

```markdown
### Commit & Submit
1. Commit with conventional message: `feat(<scope>): <description> [T<X>.<Y>]`
2. Submit PR: `gs branch submit --fill`
3. If independent next task: `gs branch create T<X>.<Y+1>-<name>`
4. If dependent next task: stack on current branch
```
