# Using git-spice with Worktrees and AI Agents

This document covers how AI agents should utilize git-spice with Git worktrees so that multiple agents can work on different branches in the same stack simultaneously, without being limited to a single directory.

## Why Worktrees Matter for Agents

In a standard Git checkout, only one branch can be active at a time. This means a single agent working on `feature-part-1` blocks any other agent from working on `feature-part-2` in the same repository directory. Git worktrees solve this by creating additional working directories, each checked out to a different branch, all sharing the same `.git` state.

Key benefits for multi-agent workflows:

- **Parallel branch work**: Multiple agents can work on different branches in the same stack concurrently
- **No interference**: Each agent has its own working directory with its own index and checkout
- **Shared git-spice state**: git-spice stores its tracking data inside `.git/`, so all worktrees see the same stack topology
- **Independent commits**: Each agent can stage, commit, and restack without affecting another agent's working directory

## Setting Up Worktrees with git-spice

### Creating Worktrees

```bash
# From the main checkout at ~/project/
git worktree add ~/project.worktrees/part-1 feature-part-1
git worktree add ~/project.worktrees/part-2 feature-part-2
```

Each worktree is a full working directory with its own checked-out branch. The `.git` file in each worktree points back to the shared `.git/` directory in the main checkout.

### git-spice State is Shared

git-spice stores branch tracking metadata (parent-child relationships, forge associations) in `.git/spice/`. Because all worktrees share the same `.git/` directory, git-spice state is automatically shared:

- Running `gs ls` in any worktree shows the same stack topology
- Creating a branch with `gs bc` in one worktree is immediately visible in all others
- Submit state (PR numbers, URLs) is shared across all worktrees

### Each Worktree Has Its Own Branch

A given branch can only be checked out in one worktree at a time. Git enforces this:

```bash
# If feature-part-1 is checked out in ~/project.worktrees/part-1/
# This will fail:
cd ~/project/ && git checkout feature-part-1
# fatal: 'feature-part-1' is already checked out at '~/project.worktrees/part-1'
```

This is actually a safety feature for agents -- it prevents two agents from accidentally working on the same branch.

## Agent Workflow Patterns

### Parallel Stack Development

A common pattern is splitting a feature into stacked branches and assigning each to a different agent:

```
trunk (main)
  +-- feature-part-1  (Agent A in ~/project.worktrees/part-1/)
       +-- feature-part-2  (Agent B in ~/project.worktrees/part-2/)
            +-- feature-part-3  (Agent C in ~/project.worktrees/part-3/)
```

**Agent A** works in `~/project.worktrees/part-1/`:

```bash
cd ~/project.worktrees/part-1
# Make changes, stage them
gs cc -m "Implement base data model"
```

**Agent B** works in `~/project.worktrees/part-2/`:

```bash
cd ~/project.worktrees/part-2
# Make changes, stage them
gs cc -m "Add API endpoints for data model"
```

Both agents can commit independently. When Agent A commits, git-spice will attempt to restack upstack branches. Branches checked out in other worktrees are skipped during restacking (see Limitations below).

### Restacking After Upstream Changes

When Agent A makes changes to `feature-part-1`, Agent B's branch (`feature-part-2`) needs rebasing. Since `feature-part-2` is checked out in another worktree, automatic restacking from Agent A's worktree will skip it.

Agent B must restack their own branch:

```bash
cd ~/project.worktrees/part-2
gs stack restack  # gs sr
```

### Syncing with Remote

```bash
# Any agent (or the orchestrator) can run sync from any worktree:
gs repo sync  # gs rs

# Branches checked out in other worktrees are skipped during deletion
# even if they have been merged on the remote
```

## Limitations and Gotchas

### Restacking Skips Other Worktree Branches

When `gs cc`, `gs ca`, or `gs sr` triggers restacking, any branch that is checked out in a different worktree is skipped. This means:

- Agent A's commit will NOT automatically rebase Agent B's branch
- Each agent must run `gs sr` in their own worktree to pick up upstream changes
- The stack may temporarily appear out of sync until all agents restack

### Branch Deletion

`gs branch delete` (and `gs repo sync`) will not delete branches that are checked out in other worktrees. Git prevents this at the filesystem level. To clean up:

1. Remove the worktree first: `git worktree remove ~/project.worktrees/part-1`
2. Then delete the branch: `gs bd feature-part-1`

Or let `gs repo sync` clean it up on the next run after the worktree is removed.

### Lock File Contention

Git uses lock files (e.g., `.git/index.lock`, `.git/refs/heads/<branch>.lock`) to prevent concurrent modifications. If two agents run git operations at exactly the same time, one will fail with a lock error.

This is particularly relevant for:

- `gs cc` / `gs ca` (both write to refs)
- `gs sr` (rebases may modify shared refs)
- `gs repo sync` (fetches and updates refs)

**If you encounter a lock error**, retry up to 3 times with a short delay. Do NOT remove the lock file -- another agent may be actively using it. See the project's rules on git lock files for more detail.

### Shared Stack Operations

Operations that affect the entire stack require coordination:

- **`gs stack submit` (`gs ss`)**: Pushes and creates/updates PRs for all branches in the stack. If two agents run this simultaneously, they may create duplicate PRs or encounter push conflicts.
- **`gs stack restack` (`gs sr`)**: If run from a worktree that is mid-stack, it will skip branches in other worktrees and may leave the stack partially restacked.

## Best Practices

### One Agent Per Worktree

Never assign two agents to the same worktree. Each worktree should have exactly one agent operating in it. This avoids:

- Index contention (two agents staging different files)
- Lock file conflicts
- Confusing commit history

### Use Worktree-Scoped Git Config

Use the `--worktree` scope for agent-specific settings:

```bash
# In each worktree, set agent-specific config
git config --worktree user.name "Agent A"
git config --worktree user.email "agent-a@example.com"
```

This prevents agents from overwriting each other's identity or preferences.

### Prefer gs Commands Over git Commands

This is always true, but especially important in worktree setups:

- `gs cc` over `git commit` -- maintains stack consistency and triggers restacking
- `gs bc` over `git checkout -b` -- tracks the branch in the stack
- `gs bd` over `git branch -d` -- rebases upstack onto the next downstack branch

### Verify Stack State Before and After Operations

Always run `gs ls` (or `gs ll` for more detail) before starting work and after completing operations:

```bash
# Before starting
gs ls

# After committing or restacking
gs ls
```

This catches situations where the stack is out of sync due to another agent's work.

### Coordinate Stack Submissions

Only one agent should run `gs stack submit` (`gs ss`) at a time. Recommended patterns:

1. **Designated submitter**: One agent (or the orchestrator) is responsible for all `gs ss` calls
2. **Sequential submission**: Agents signal when they are done, and submission happens after all agents have committed and restacked
3. **Branch-level submission** (preferred for multi-agent setups): Each agent submits only their own branch with `gs branch submit` (`gs bs`) instead of submitting the whole stack. This avoids force-pushing branches owned by other agents and allows CI to start per-branch. See the "Coordinated Restack Workflow" section for the full pattern including restack coordination and conflict ownership.

### Handling Merge Conflicts During Restack

When Agent B runs `gs sr` and encounters a conflict caused by Agent A's changes:

1. Resolve the conflict in the affected files
2. Stage resolved files with `git add`
3. Run `gs rebase continue` (`gs rbc`)
4. Verify with `gs ls` that the stack looks correct

If the conflict is too complex, abort with `gs rebase abort` (`gs rba`) and coordinate with the other agent or the user.

## Coordinated Restack Workflow

When multiple agents have branches checked out in separate worktrees across a stack, restacking requires explicit coordination. The standard `gs stack restack` skips branches in other worktrees, so a dedicated restack coordinator must orchestrate the process.

### Restack Coordinator Pattern

A dedicated agent or coordinator runs the restack from the bottom of the stack and then visits each worktree sequentially:

1. **Start from the bottom branch** of the stack
2. Run `gs stack restack` — this restacks any branches NOT checked out in other worktrees
3. For each branch checked out in a worktree (bottom to top), cd into that worktree and run:
   ```bash
   cd /path/to/repo.worktrees/<branch-worktree>
   gs branch restack  # restacks just this branch onto its updated parent
   ```
4. After each branch is restacked, immediately push it (see below)

The coordinator must process worktrees **bottom to top** — a branch cannot be restacked until its parent has been restacked and pushed.

### Push After Each Restack, Not at the End

Do NOT batch all pushes with a single `gs stack submit` at the end. Instead, each branch should be pushed individually as soon as it's restacked:

```bash
cd /path/to/repo.worktrees/<branch-worktree>
gs branch restack   # restack this branch
gs branch submit    # push immediately
```

Benefits of push-per-branch:
- **CI starts sooner** — each branch's CI pipeline begins as soon as it's pushed, rather than waiting for the entire stack
- **Incremental progress** — if a later branch has conflicts, earlier branches are already updated on the remote
- **Smaller blast radius** — issues are isolated to individual branches rather than a single large push

### Conflict Resolution Ownership

Each branch's owning agent is responsible for resolving conflicts on their branch:

1. The restack coordinator runs `gs branch restack` in a worktree
2. If a conflict occurs, the coordinator **does not resolve it** — they flag it to the branch owner
3. The branch owner resolves the conflict:
   ```bash
   # In the branch's worktree
   # ... resolve conflicts in affected files ...
   git add <resolved-files>
   gs rebase continue   # gs rbc
   ```
4. The branch owner then pushes their branch: `gs branch submit`
5. The coordinator continues restacking the next branch up the stack

If the branch owner is unavailable, the coordinator may resolve simple conflicts (e.g., trivial merge markers), but complex conflicts should always be handled by the agent with context on those changes.

### Example: Coordinated Restack

```
Stack:  main → part-1 (Agent A) → part-2 (Agent B) → part-3 (Agent C)
```

After `main` is updated (e.g., via `gs repo sync`):

```bash
# === Restack Coordinator ===

# Step 1: Run stack restack from bottom (skips worktree branches)
cd /path/to/main-checkout
gs stack restack

# Step 2: Restack part-1 in its worktree
cd /path/to/repo.worktrees/part-1
gs branch restack
gs branch submit    # push immediately

# Step 3: Restack part-2 in its worktree
cd /path/to/repo.worktrees/part-2
gs branch restack
gs branch submit    # push immediately

# Step 4: Restack part-3 in its worktree
cd /path/to/repo.worktrees/part-3
gs branch restack
gs branch submit    # push immediately
```

If step 3 encounters a conflict, the coordinator notifies Agent B, who resolves it in their worktree before the coordinator proceeds to step 4.

## Example: Full Multi-Agent Workflow

```bash
# === Setup (orchestrator or user) ===
cd ~/project
gs repo init --trunk main --remote origin
gs bc feature-part-1
gs bc feature-part-2
gs bc feature-part-3

# Create worktrees
git worktree add ~/project.worktrees/part-1 feature-part-1
git worktree add ~/project.worktrees/part-2 feature-part-2
git worktree add ~/project.worktrees/part-3 feature-part-3

# === Agent A (in ~/project.worktrees/part-1/) ===
cd ~/project.worktrees/part-1
# ... implement part 1 ...
gs cc -m "Implement part 1"
gs ls  # verify stack state

# === Agent B (in ~/project.worktrees/part-2/) ===
cd ~/project.worktrees/part-2
gs sr  # restack to pick up Agent A's changes
# ... implement part 2 ...
gs cc -m "Implement part 2"
gs ls  # verify stack state

# === Agent C (in ~/project.worktrees/part-3/) ===
cd ~/project.worktrees/part-3
gs sr  # restack to pick up changes from A and B
# ... implement part 3 ...
gs cc -m "Implement part 3"
gs ls  # verify stack state

# === Submit (each agent pushes their own branch) ===
# Agent A:
cd ~/project.worktrees/part-1
gs bs --fill  # submit just this branch

# Agent B:
cd ~/project.worktrees/part-2
gs bs --fill  # submit just this branch

# Agent C:
cd ~/project.worktrees/part-3
gs bs --fill  # submit just this branch

# Or: a coordinator can restack and submit each branch sequentially
# See "Coordinated Restack Workflow" section above
```

## References

- [git-spice Official Docs](https://abhinav.github.io/git-spice/)
- [Git Worktrees Documentation](https://git-scm.com/docs/git-worktree)
- [git-spice CLI Reference](https://abhinav.github.io/git-spice/cli/reference/)
- `references/cli-reference.md` in this plugin for the complete CLI reference
