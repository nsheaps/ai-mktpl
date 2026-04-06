---
name: review-commits
description: >
  Review commit structure and organization. Use when asked to "review commits",
  "check commit history", "are commits atomic", "review commit structure",
  or when evaluating whether commits are logically grouped and ordered.
argument-hint: "[PR number or branch name]"
---

# Review Commits

Evaluate commit structure for atomicity, logical grouping, and clean history.

## What to Evaluate

| Dimension    | Check for                                                  |
| ------------ | ---------------------------------------------------------- |
| Atomicity    | Does each commit do exactly one thing?                     |
| Ordering     | Do commits build logically on each other?                  |
| Grouping     | Are related changes in the same commit?                    |
| Bisectability| Could `git bisect` find a bug introduced by one commit?    |
| No fixups    | Are there "fix typo" or "oops" commits that should be squashed? |

## Process

1. List commits on the branch: `git log --oneline <base>..HEAD`
2. For each commit, check that it is self-contained and buildable
3. Verify no commit mixes unrelated changes
4. Flag fixup commits that should be squashed
5. Check that the commit sequence tells a readable story

## Output

- Commit list with assessment of each
- Recommendations for squashing, reordering, or splitting
- Overall structure score
