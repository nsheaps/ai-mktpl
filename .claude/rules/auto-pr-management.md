# Automatic PR Creation and Updates

## Rule: Every Branch Gets a PR

**All sessions MUST automatically create and maintain a pull request for their working branch.**

## When to Create a PR

Create a PR **after the first push** to a new branch. Do not wait for the user to ask.

## When to Update a PR

Update the PR description **after every push** to reflect the current state of changes. Keep the description accurate and up-to-date as work progresses.

## How to Authenticate

Use the `GH_TOKEN` environment variable with the `gh` CLI. This token has write access to pull requests and issues.

```bash
eval "$(mise activate bash)"
```

The `gh` CLI should already be configured via the mise-managed GitHub plugin. If `gh` is not available, install it via `mise install`.

## Creating a PR

```bash
gh pr create \
  --title "Short descriptive title" \
  --body "$(cat <<'EOF'
## Summary
- What changed and why

## Test plan
- [ ] Verification steps

<session-link>
EOF
)" \
  --hostname github.com
```

- Use `--draft` if the work is still in progress
- Target the default branch (usually `main`) unless the task specifies otherwise
- Include a session link if available

## Updating an Existing PR

After subsequent pushes, update the PR body to reflect all changes:

```bash
gh pr edit <number-or-branch> \
  --body "$(cat <<'EOF'
Updated description here
EOF
)" \
  --hostname github.com
```

## Checking for an Existing PR

Before creating, check if a PR already exists for the current branch:

```bash
gh pr view --json number,title,state --hostname github.com 2>/dev/null
```

If a PR already exists, update it instead of creating a new one.

## PR Title Conventions

- Keep under 70 characters
- Start with a verb (Add, Fix, Update, Refactor, etc.)
- Match conventional commit style when applicable

## Draft vs Ready

- Use `--draft` when work is incomplete or experimental
- Mark ready with `gh pr ready` when the work is complete and CI passes
