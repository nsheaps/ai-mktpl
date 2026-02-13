# Tracking External Branches with git-spice

How to use someone else's PR branch as a base for your own stack, and the pitfalls to avoid.

> Sources:
> - [git-spice CLI Reference](https://abhinav.github.io/git-spice/cli/reference/)
> - [git-spice Limitations](https://abhinav.github.io/git-spice/guide/limits/)
> - [git-spice Source: stack_submit.go](https://github.com/abhinav/git-spice/blob/main/stack_submit.go)
> - [git-spice Source: submit handler](https://github.com/abhinav/git-spice/blob/main/internal/handler/submit/handler.go)
> - [git-spice DESIGN.md](https://github.com/abhinav/git-spice/blob/main/DESIGN.md)

---

## Use Case

You want to restack your branches on top of a colleague's PR branch so you can resolve conflicts against their changes (which will land on main soon). But you never want your `gs` operations to push to, modify, or submit PRs for their branch.

## TL;DR

**git-spice has no built-in "read-only" or "skip-on-submit" concept for tracked branches.** If you track an external branch, batch submit commands (`gs ss`, `gs dss`) will attempt to push to it and create/update a CR for it. This can overwrite the original author's branch with `--force-with-lease`.

The safe approach is to **avoid tracking the external branch** and instead use `gs upstack onto` or `gs branch onto` to set it as a base, combined with `gs upstack submit` (not `gs stack submit`) to submit only your own branches.

---

## How It Works

### Can `gs branch track` track a remote branch you don't own?

**Yes, technically.** `gs branch track` operates on local branches. If you have a local branch that tracks a remote branch (e.g., `git checkout --track origin/their-branch`), you can run `gs bt their-branch --base main` to add it to git-spice's tracking.

However, this is where the danger begins. Once tracked, git-spice treats it like any other branch in your stack -- it will attempt to push to it and manage CRs for it during batch submit operations.

### What happens during `gs stack submit`?

**`gs stack submit` submits ALL non-trunk tracked branches in the stack.** From the [source code](https://github.com/abhinav/git-spice/blob/main/stack_submit.go):

```go
// Simplified from stack_submit.go
for _, branch := range stack {
    if branch == store.Trunk() {
        continue  // Only trunk is skipped
    }
    toSubmit = append(toSubmit, branch)
}
```

There is no ownership check, no read-only flag, and no per-branch skip mechanism. The only branch excluded is trunk.

**The push uses `--force-with-lease`**, which means:
- If the remote branch has been updated since your last fetch, the push will fail (safe).
- If you recently fetched (which `gs repo sync` does), the lease will match and **the push will succeed**, potentially overwriting the original author's commits with your local version of their branch.

### Can you set a branch as read-only or skip-on-submit?

**No.** As of git-spice's current version, there is no configuration option, flag, or mechanism to mark a tracked branch as "do not push" or "do not submit." The relevant configuration keys (`spice.submit.*`) apply globally, not per-branch.

### What happens with `gs repo sync` when the external branch gets merged?

When the external PR is merged into trunk:

1. `gs repo sync` pulls the latest trunk and detects merged CRs.
2. If the external branch has an associated CR that git-spice knows about, it will be detected as merged and deleted from tracking.
3. Your branches that were stacked on top of it will need restacking -- their base will shift to trunk (or the next available downstack branch).
4. Run `gs stack restack` (or `gs repo sync --restack`) to rebase your branches onto the updated trunk.

**If you never submitted a CR for the external branch** (because you used the safe workflow below), git-spice may not automatically detect it as merged. You may need to manually untrack it with `gs branch untrack their-branch` and then restack.

### Are there config options to control this behavior?

**No per-branch config exists.** The closest options are:

| Config/Flag | What It Does | Helps? |
|---|---|---|
| `--update-only` | Only update existing CRs, skip new ones | Partially -- prevents creating a NEW CR, but if the branch already has one, it still pushes and updates |
| `--no-publish` | Push without creating CRs | No -- still pushes the branch |
| `spice.submit.updateOnly` | Default `--update-only` | Same limitation as above |

None of these prevent the push itself.

---

## Recommended Workflow: Safe Stacking on External Branches

### Strategy: Don't Track the External Branch

The safest approach is to **not track** the external branch in git-spice at all. Instead, use it purely as a rebase target via `gs upstack onto`.

### Step-by-Step

#### 1. Fetch and create a local copy of the external branch

```bash
git fetch origin their-branch
git checkout --track origin/their-branch
# or if you already have it:
git checkout their-branch
git pull
```

#### 2. Do NOT track it with git-spice

Do **not** run `gs branch track their-branch`. Leave it as an untracked branch that git-spice ignores.

#### 3. Move your stack onto the external branch

From the bottom of your stack (the branch that should sit on top of the external branch):

```bash
gs upstack onto their-branch
```

This rebases your branch (and all upstack branches) onto `their-branch`. git-spice records `their-branch` as the base in its internal state, but since `their-branch` is not tracked, batch submit commands will not try to push it.

#### 4. Submit only YOUR branches

Use `gs upstack submit` from the bottom of your stack, **not** `gs stack submit`:

```bash
# Navigate to the bottom of YOUR stack (first branch above the external one)
gs bco my-first-branch

# Submit from here upward
gs upstack submit --fill
```

**Critical distinction:**
- `gs upstack submit` starts from the current branch and goes up. It requires the base branch to "have already been submitted by a prior command" OR to be trunk. Since the external branch already has a PR (from the other author), this condition is satisfied.
- `gs stack submit` walks the entire stack and submits everything, which would try to push the untracked branch (and likely error or cause unexpected behavior).

If `gs upstack submit` complains that the base hasn't been submitted, use `gs branch submit` individually for each of your branches, or use `--no-prompt` if available.

#### 5. Keep your local copy of the external branch up to date

Periodically sync with the external branch as the other author pushes updates:

```bash
git checkout their-branch
git pull
git checkout my-first-branch
gs stack restack   # Rebase your stack onto the updated external branch
```

#### 6. When the external PR merges

Once the external PR is merged into main:

```bash
# Sync with remote
gs repo sync

# Move your stack back onto trunk
gs bco my-first-branch
gs upstack onto main

# Restack and resubmit
gs stack restack
gs stack submit
```

---

## Alternative Workflow: Track and Use `--update-only`

If you prefer to track the external branch (for visibility in `gs ls`), you can partially mitigate the risks:

### Step-by-Step

1. Track the external branch: `gs bt their-branch --base main`
2. Stack your branches on top: `gs bc my-first-branch` (from `their-branch`)
3. **Always use `--update-only`** for batch submits: `gs ss --update-only`
4. Submit your branches individually the first time: `gs bs` on each branch
5. After that, `gs ss --update-only` will only update branches that already have CRs

### Why this is riskier

- If you forget `--update-only` even once, git-spice will push to the external branch and potentially create a duplicate CR.
- `--update-only` still pushes branches with existing CRs. If you accidentally submitted the external branch once (creating a CR), subsequent `--update-only` calls will keep pushing to it.
- `--force-with-lease` may succeed if you recently fetched, overwriting the author's branch.

---

## Pitfalls and Safety Considerations

### The `--force-with-lease` Danger

git-spice pushes branches using `--force-with-lease`. This is normally safe for your own branches (it prevents overwriting concurrent changes). But for an external branch:

- After `git fetch` or `gs repo sync`, your local tracking ref is updated.
- A subsequent `git push --force-with-lease` will compare against the freshly fetched ref, and **succeed**.
- This effectively force-pushes YOUR local version of their branch to the remote, overwriting their work.

**Mitigation:** Never track the external branch. Use the recommended workflow above.

### Accidental `gs stack submit`

If you run `gs ss` instead of `gs uss`, it walks the full stack and may try to push or submit for the external branch. With the recommended workflow (untracked external branch), this may error rather than silently push, but the behavior is not well-defined for untracked base branches.

**Mitigation:** Train yourself to use `gs upstack submit` when your stack has an external base. Consider setting an alias.

### `gs repo sync` May Not Detect the External Merge

If you never submitted a CR for the external branch via git-spice, `gs repo sync` will not know it was merged. The branch will remain in your local tracking state as a stale base.

**Mitigation:** After the external PR merges, manually run:
```bash
gs bco my-first-branch
gs upstack onto main
# If the external branch was tracked:
gs branch untrack their-branch
git branch -d their-branch
```

### Restack Conflicts

When the external author pushes updates, rebasing your stack onto their changes may produce conflicts. This is expected and normal -- resolve conflicts with `git add` + `gs rbc` as usual.

### Navigation Confusion

If the external branch is untracked, `gs up` / `gs down` / `gs ls` will not show it in the stack visualization. Your bottom branch will appear to be based on an invisible branch. This is cosmetic but can be confusing.

---

## Summary

| Question | Answer |
|---|---|
| Can you track an external branch? | Yes, but you probably shouldn't |
| Does `gs stack submit` push all branches? | Yes, all non-trunk tracked branches |
| Can you skip a branch during submit? | No built-in mechanism |
| Can you mark a branch read-only? | No |
| Will `--force-with-lease` protect the external branch? | Not after a recent fetch |
| Recommended approach? | Don't track; use `gs upstack onto` + `gs upstack submit` |
| What to do when the external PR merges? | `gs upstack onto main` to move stack back to trunk |
