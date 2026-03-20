# Automatic PR Creation and Updates

## Rule: Every Branch Gets a PR

**All sessions MUST automatically create and maintain a pull request for their working branch.**

## When to Create a PR

Create a PR **after the first push** to a new branch. Do not wait for the user to ask.

## When to Update a PR

Update the PR description **after every push** to reflect the current state of changes. Keep the description accurate and up-to-date as work progresses.

## How to Authenticate

Use the `GH_TOKEN` environment variable with the `gh` CLI. Since the git remote in web sessions is a local proxy, use `gh api` with `--hostname github.com` for all GitHub API calls (not `gh pr create` which requires a GitHub remote).

```bash
eval "$(mise activate bash)"
```

The `gh` CLI should already be configured via the mise-managed GitHub plugin. If `gh` is not available, install it via `mise install`.

## Creating a PR

**Always create PRs as drafts.** After creation, add the `request-review` label to trigger an AI code review.

```bash
eval "$(mise activate bash)"

# Create draft PR via API (works with local proxy remote)
gh api repos/nsheaps/ai-mktpl/pulls \
  --hostname github.com \
  --method POST \
  --field title="Short descriptive title" \
  --field head="<branch-name>" \
  --field base="main" \
  --field draft=true \
  --field body="$(cat <<'EOF'
## Summary
- What changed and why

## Test plan
- [ ] Verification steps

<session-link>
EOF
)" --jq '.number'

# Add request-review label to trigger AI review
gh api repos/nsheaps/ai-mktpl/issues/<PR_NUMBER>/labels \
  --hostname github.com \
  --method POST \
  --field 'labels[]=request-review'
```

- Target the default branch (usually `main`) unless the task specifies otherwise
- Include a session link if available

## Updating an Existing PR

After subsequent pushes, update the PR body to reflect all changes:

```bash
gh api repos/nsheaps/ai-mktpl/pulls/<PR_NUMBER> \
  --hostname github.com \
  --method PATCH \
  --field body="$(cat <<'EOF'
Updated description here
EOF
)"
```

## Checking for an Existing PR

Before creating, check if a PR already exists for the current branch:

```bash
gh api repos/nsheaps/ai-mktpl/pulls \
  --hostname github.com \
  --jq '.[] | select(.head.ref == "<branch-name>") | {number, title, state}'
```

If a PR already exists, update it instead of creating a new one.

## PR Title Conventions

- Keep under 70 characters
- Start with a verb (Add, Fix, Update, Refactor, etc.)
- Match conventional commit style when applicable

## PR Lifecycle

1. **Create as draft** — all new PRs start as drafts
2. **Add `request-review` label** — triggers AI code review automatically
3. **Address review feedback** — fix any issues found by the AI review
4. **Mark ready** when work is complete and CI passes:
   ```bash
   gh api repos/nsheaps/ai-mktpl/pulls/<PR_NUMBER> \
     --hostname github.com \
     --method PATCH \
     --field draft=false
   ```
