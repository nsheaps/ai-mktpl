---
name: pr-review-workflow
description: >
  Quick-reference index for the full PR review workflow. Redirects to
  automated-code-review for the full orchestration. Use when asked to "do a
  full review", "review everything", or "comprehensive review".
argument-hint: "[PR number or branch name]"
---

# PR Review Workflow

**This skill is a quick-reference index. For the full orchestrated workflow, use `scm-utils:automated-code-review`.**

## Available Granular Review Skills

Use individually when you only need one dimension, or use `automated-code-review` for the full sequence.

| Skill                              | What it covers                         |
| ---------------------------------- | -------------------------------------- |
| `scm-utils:review-code`            | Code quality, patterns, bugs, security |
| `scm-utils:review-diff`            | Diff scope and completeness            |
| `scm-utils:review-commits`         | Commit structure and atomicity         |
| `scm-utils:review-commit-messages` | Commit message quality and conventions |
| `scm-utils:review-pr-contents`     | PR title, body, labels, metadata       |
| `scm-utils:validate-review`        | Verify findings are accurate           |
| `scm-utils:post-review`            | Format and submit the review on GitHub |
| `scm-utils:fix-review-findings`    | Address review findings in code        |

## When to Use What

- **Full review?** Use `scm-utils:automated-code-review`
- **Just checking code quality?** Use `scm-utils:review-code` alone
- **Just checking the diff scope?** Use `scm-utils:review-diff` alone
- **Just checking PR presentation?** Use `scm-utils:review-pr-contents` alone
- **CI-based review (Henry's workflow)?** Use `scm-utils:code-review`
- **Iterate until quality threshold met?** Use `sdlc-utils:iterate-until-good`

## External References

- [Google Engineering Practices: Code Review](https://google.github.io/eng-practices/review/)
- [Conventional Comments](https://conventionalcomments.org/)
