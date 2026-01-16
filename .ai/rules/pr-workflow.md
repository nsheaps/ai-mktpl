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

## When to Move from Draft

Move PR from draft to ready when:

- All planned work is complete
- Tests pass
- You've self-reviewed the changes
- Ready for actual review

```bash
gh pr ready <number>
```
