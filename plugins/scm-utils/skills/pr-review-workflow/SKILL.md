---
name: pr-review-workflow
description: >
  Full PR review workflow using all granular review skills in sequence. Use when
  asked to "do a full review", "review everything on this PR", "comprehensive
  review", or when you need the complete review process from start to finish.
argument-hint: "[PR number or branch name]"
---

# PR Review Workflow

A complete PR review using all granular review skills in the correct sequence.

<!-- TODO: Compare this meta+granular pattern vs having one comprehensive skill
     with supplementary docs. Validate which approach agents find more effective.
     Track findings in docs/research/ when evaluated. -->

## Sequence

### Phase 1: Understand Context

1. Fetch the PR metadata and description
2. Identify the base branch and full diff

### Phase 2: Review (run in parallel where possible)

| Step | Skill                              | What it covers                 |
| ---- | ---------------------------------- | ------------------------------ |
| 2a   | `scm-utils:review-code`            | Code quality, patterns, bugs   |
| 2b   | `scm-utils:review-diff`            | Diff scope and completeness    |
| 2c   | `scm-utils:review-commits`         | Commit structure and atomicity |
| 2d   | `scm-utils:review-commit-messages` | Commit message quality         |
| 2e   | `scm-utils:review-pr-contents`     | PR title, body, metadata       |

Steps 2a-2e can run in parallel as sub-agents.

### Phase 3: Validate

Use `scm-utils:validate-review` to confirm findings are accurate and not false positives.

### Phase 4: Post

Use `scm-utils:post-review` to submit the review on GitHub with inline comments and a summary.

### Phase 5: Iterate (if needed)

If the author fixes issues and requests re-review:

1. Use `scm-utils:respond-to-review` to handle comment threads
2. Use `scm-utils:fix-review-findings` if you are the author fixing issues
3. Re-run Phase 2 on the updated code
4. For a full iterate-until-good loop, use `sdlc-utils:iterate-until-good`

## When to Use Each Skill Individually

- **Just checking code quality?** Use `review-code` alone
- **Just checking the diff scope?** Use `review-diff` alone
- **Just checking PR presentation?** Use `review-pr-contents` alone
- **Full review?** Use this workflow

## External References

- [Google Engineering Practices: Code Review](https://google.github.io/eng-practices/review/)
- [Conventional Comments](https://conventionalcomments.org/)
