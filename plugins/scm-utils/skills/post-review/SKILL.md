---
name: post-review
description: >
  Post or update a review on GitHub. Use when asked to "post the review",
  "submit review", "leave a review on the PR", "update the review", or
  when you have review findings ready to publish on a pull request.
argument-hint: "[PR number]"
---

# Post Review

Submit a structured review on a GitHub pull request.

## Process

1. **Create a pending review**: `gh api repos/{owner}/{repo}/pulls/{number}/reviews --method POST`
2. **Add inline comments** on specific lines using the review's pending state
3. **Submit the review** with a summary and verdict

## Review Verdicts

| Verdict           | When to use                                             |
| ----------------- | ------------------------------------------------------- |
| `APPROVE`         | No outstanding issues, ready to merge                   |
| `COMMENT`         | Suggestions but not blocking                            |
| `REQUEST_CHANGES` | Must fix before merge (security, correctness, breaking) |

## Summary Format

Use collapsible `<details>/<summary>` with shields.io badges for scores:

```markdown
<details>
<summary>Review: Quality 85% | Security 92% | Simplicity 78%</summary>

[Detailed findings here]

</details>

**Follow-ups:**
- [ ] Item that should be tracked separately
```

## Guidelines

- Post inline comments on the specific lines they reference
- Keep the summary concise -- details go in inline comments
- Use conventional comment prefixes: `suggestion:`, `question:`, `issue:`, `nitpick:`
- Include a workflow run link or session reference in the footer
- When updating an existing review, resolve addressed threads first

## References

- [GitHub Pull Request Reviews API](https://docs.github.com/en/rest/pulls/reviews)
- [Conventional Comments](https://conventionalcomments.org/)
