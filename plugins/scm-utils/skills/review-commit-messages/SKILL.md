---
name: review-commit-messages
description: >
  Review commit message quality. Use when asked to "review commit messages",
  "check commit message format", "are commit messages good", or when evaluating
  whether commit messages are conventional, descriptive, and useful.
argument-hint: "[PR number or branch name]"
---

# Review Commit Messages

Evaluate commit message quality for clarity, convention, and usefulness.

## What to Evaluate

| Dimension   | Check for                                                    |
| ----------- | ------------------------------------------------------------ |
| Format      | Follows conventional commits or repo convention?             |
| Subject     | Under 72 chars, imperative mood, no trailing period?         |
| Body        | Explains "why" not just "what"? Wrapped at 72 chars?         |
| References  | Links to issues/PRs where relevant?                          |
| Consistency | All messages on the branch follow the same style?            |

## Process

1. List commits with full messages: `git log <base>..HEAD`
2. Check each message against the conventions above
3. Verify the subject line is meaningful (not "fix", "update", "wip")
4. Check that the body adds context beyond what the diff shows
5. Flag messages that need rewriting

## Output

- Per-commit assessment of message quality
- Specific rewording suggestions for weak messages
- Overall quality score

## References

- [Conventional Commits](https://www.conventionalcommits.org/)
- [How to Write a Git Commit Message](https://cbea.ms/git-commit/)
