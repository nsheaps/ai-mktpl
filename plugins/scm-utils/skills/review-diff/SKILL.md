---
name: review-diff
description: >
  Review the diff against the base branch. Use when asked to "review the diff",
  "check what changed", "review changes against main", "is this PR complete",
  or when evaluating whether a diff is scoped correctly and complete.
argument-hint: "[PR number or branch name]"
---

# Review Diff

Evaluate the diff against the base branch for scope, completeness, and coherence.

## What to Evaluate

| Dimension    | Check for                                                |
| ------------ | -------------------------------------------------------- |
| Scope        | Does the diff match the stated goal? No unrelated changes? |
| Completeness | Are all necessary changes included? Nothing missing?     |
| Coherence    | Do the changes form a logical whole?                     |
| Reversibility| Could this be cleanly reverted if needed?                |
| Side effects | Does the diff touch files it shouldn't?                  |

## Process

1. Get the full diff against the base branch: `git diff <base>...HEAD`
2. List all changed files and categorize them (core changes vs supporting)
3. Compare the diff scope to the PR description or stated goal
4. Check for missing changes (tests, docs, config updates)
5. Flag any unrelated changes that should be in a separate PR

## Output

- List of changed files with categorization
- Scope assessment: on-target, over-scoped, or under-scoped
- Missing changes that should be included
- Unrelated changes that should be removed
