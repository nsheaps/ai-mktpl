# Pull Request Workflow

## Draft PR on First Commit

**When working on a feature branch:** As soon as you make your first commit, immediately open a draft PR and assign it to the appropriate reviewer.

```bash
# After first commit and push
gh pr create --draft --assignee <username> --title "..." --body "..."
```

## Update PR Description on Each Push

**Every time you push new commits to the remote:** Update the PR description to reflect the current state.

### PR Description Structure

The PR description should always reflect:

1. **What the PR does** - Current functionality/changes
2. **Current status** - What's complete, what's next
3. **What to review** - What you expect the reviewer to focus on

### What NOT to Include

- ❌ Detailed changelog of recent commits
- ❌ Historical context of prior iterations
- ❌ Long explanations of what changed since last update

### Update Pattern

```bash
# After pushing new commits
gh pr edit <number> --body "$(cat <<'EOF'
[Updated PR description reflecting current state]
EOF
)"
```

## Keep PRs Focused

**CRITICAL:** PRs must contain only changes related to the intended scope.

### Before Marking Ready

1. Run `gh pr diff <number> --name-only` to list changed files
2. Verify each file is relevant to the PR's purpose
3. Remove any unrelated changes (CI auto-commits, formatting drift, etc.)

### If Unrelated Changes Appear

- **CI auto-commits:** Reset to your last commit and force push
- **Formatting changes to unrelated files:** Investigate root cause, file an issue if it's a CI bug
- **Accidental modifications:** Use `git checkout origin/main -- <file>` to restore

### Why This Matters

- Reviewers shouldn't waste time on unrelated changes
- Merge conflicts are harder to resolve with extra files
- Git history becomes unclear when PRs touch unrelated code
- Rollbacks are harder when changes are mixed

## Requesting a Fresh AI Review

If the PR is still in draft, apply the `request-review` label to force a review — non-draft PRs get reviewed automatically on every push. The review receiver removes the label the moment a review starts, so a label sitting on the PR always means "not yet reviewed." To request another round after addressing feedback (a pushed fix, or just a reply justifying why you didn't change something), re-apply the label. See `pr-management.md`'s "Requesting a Fresh AI Review" section for the full loop and the CI-green/mergeable/approved gate that must hold before engaging the user.

## When a PR Is Ready to Leave Draft

**Only the user/handler moves a PR out of draft** — see `pr-management.md` rule 5. Never run `gh pr ready` on an agent-authored PR. The criteria below are what makes a PR *ready for that decision*, so drive toward them and then hand off:

- All planned work is complete
- Tests pass
- You've self-reviewed the changes
- The AI review agent has approved (see "Requesting a Fresh AI Review" above)

For reference, the command the user runs is:

```bash
gh pr ready <number>
```
