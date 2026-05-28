# Pull Request Management

## PR Body and Title Updates (CRITICAL)

After each push, evaluate whether the PR title and body need updating to accurately reflect the full set of changes in the PR. Your agent runtime may surface a periodic reminder hook — when it does, act on it; when it doesn't, use your judgment.

- The PR title and body describe the **cumulative changes** in the PR and how they relate to the user's original request. They are NOT a description of the most recent commit or push.
- Before updating, evaluate the full commit history, commit messages, and diffs on the branch so you properly understand the complete scope of changes.
- Keep the PR title concise (under 70 characters) and the body well-structured with a summary and test plan.

## PR Lifecycle (CRITICAL)

You are expected to open and maintain PRs. Follow these rules:

1. **Open PRs in draft**: Always create PRs in draft state (`gh pr create --draft`). Never move a PR from draft to ready-for-review — that is the user's responsibility.
2. **Assign the repo owner**: Always assign the appropriate reviewer/assignee on PRs you create (check CODEOWNERS or repo settings).
3. **Keep PRs up to date**: Update the PR title, body, and labels as the branch evolves.
4. **Close duplicates**: If one PR duplicates functionality from another or resolves an issue, use GitHub magic phrases (e.g., `Closes #123`, `Fixes #456`) in the PR body to link and close appropriately.
5. **Never mark ready for review**: Do NOT remove the draft status from a PR. Only the user may do that.
