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

## Requesting a Fresh AI Review (`request-review` label)

The `request-review` label is what forces a review on a still-draft PR (non-draft PRs get reviewed automatically on every push). Where the review workflow clears the label at review-start (ai-mktpl does — see the `Remove request-review label` step in `.github/workflows/claude-code-review.yaml`), a label sitting on the PR means "a review hasn't started yet" rather than a stale leftover; where it doesn't, the label may simply be left over from an earlier round. Either way, **re-applying the label** is the correct way to ask for another look:

1. Address the AI review's feedback — either push a fix, or reply in the review thread explaining why you're not changing something (a justification is a valid response, not just a code change).
2. Re-apply the `request-review` label (remove + re-add, or just add if it's already gone) to request a fresh review round.
3. Repeat until the review agent approves.

**Do not remove-then-re-add the label after every ordinary push just to force a re-trigger.** That workaround was needed when the label used to sit "on" indefinitely after firing once on a draft PR. Where the receiver clears it at review-start, it no longer is; where it doesn't, remove and re-add rather than assuming a present label is still doing something. Re-apply the label specifically when you want a new review round — after addressing feedback, not after every unrelated commit.

**Gate before engaging the user:** only once (a) CI is green, (b) the PR is mergeable with no conflicts, AND (c) the review agent has approved, should you — while keeping the PR in draft — reach out to the user/handler for their own review.
