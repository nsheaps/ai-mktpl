---
name: review-pr-contents
description: >
  Review PR title, body, labels, and metadata. Use when asked to "review the PR",
  "check PR description", "is the PR body good", "review PR metadata", or when
  evaluating whether a PR is well-presented for reviewers.
argument-hint: "[PR number]"
---

# Review PR Contents

Evaluate PR title, body, labels, and metadata for completeness and clarity.

## What to Evaluate

| Dimension   | Check for                                         |
| ----------- | ------------------------------------------------- |
| Title       | Under 70 chars, starts with verb, descriptive?    |
| Summary     | Explains what changed and why?                    |
| Test plan   | Includes verification steps?                      |
| Links       | References related issues, specs, or discussions? |
| Labels      | Appropriate labels applied?                       |
| Assignees   | Reviewer/assignee set?                            |
| Draft state | Draft if still in progress, ready if complete?    |

## Process

1. Fetch PR metadata: `gh pr view <number> --json title,body,labels,assignees,isDraft`
2. Evaluate each dimension
3. Compare the PR body against the actual diff to ensure accuracy
4. Flag missing or misleading information

## Output

- Assessment of each dimension
- Specific suggestions for improvement
- Whether the PR is ready for review or needs updates
