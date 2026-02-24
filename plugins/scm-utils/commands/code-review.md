---
name: code-review
description: >
  Code review a pull request. Triggers on "review this PR", "code review",
  "review PR #123", "request a review", or similar phrases.
---

# Code Review Command

Request or trigger a code review for a pull request.

## Usage

```
/code-review [PR number | PR URL | branch name]
```

If no argument is given, uses the current branch's associated PR.

## Steps

1. **Resolve the PR**: Determine the PR number from the argument, current branch, or ask the user.

2. **Check if CI review bot is available**: Look for `.github/workflows/claude-code-review.yaml` in the repository.

3. **If review bot workflow exists**:
   - Add the `request-review` label to the PR to trigger the CI review bot:
     ```bash
     gh pr edit <PR_NUMBER> --add-label "request-review"
     ```
   - Inform the user: "Triggered the review bot. It will post a review on the PR shortly."

4. **If review bot workflow does NOT exist**:
   - Recall the `code-review` skill for review guidance
   - Perform a local review using the `pr-review-toolkit:review-pr` skill or the `code-review:code-review` agent
   - Post the review directly on the PR

## Notes

- The CI review bot is preferred over local review because it runs in an isolated environment with proper GitHub App auth
- The `request-review` label is automatically removed once the review starts
- For draft PRs, the `request-review` label triggers a one-time review; use `always-review` for persistent review on drafts
