---
name: automated-code-review
description: >
  Perform a comprehensive automated code review using granular review skills.
  Orchestrates review-pr-contents, review-commits, review-commit-messages,
  review-diff, review-code, validate-review, and post-review as building blocks.
  Use this for new review workflows — scm-utils:code-review is maintained for
  backward compatibility with Henry's CI workflow.
argument-hint: "[PR number or branch name]"
---

> **Note:** `scm-utils:code-review` is the legacy skill used by Henry's CI review workflow. This skill is the recommended replacement for new review workflows.

# Automated Code Review

A comprehensive code review workflow that orchestrates multiple granular review skills in sequence. Each skill performs a focused review dimension, then results are validated and posted as a structured GitHub review.

## Review Sequence

The automated code review runs the following skills in order:

1. **review-pr-contents** — Check PR title, body, labels, and metadata for completeness and clarity
2. **review-commits** — Evaluate commit structure, atomicity, and whether commits are focused and logical
3. **review-commit-messages** — Verify commit messages follow conventions and clearly describe changes
4. **review-diff** — Check the diff against the base branch for scope, completeness, and coherence
5. **review-code** — Evaluate code quality, patterns, correctness, security, and maintainability
6. **validate-review** — Verify that all findings are accurate and actionable (not false positives)
7. **post-review** — Format and submit the review on GitHub with a structured summary and verdict

### If Issues Are Found

If review findings indicate problems that should be fixed:

1. **fix-review-findings** — Address each finding in the code
2. **Re-review** — Run the review sequence again to verify fixes

## What Gets Reviewed

### PR Contents (review-pr-contents)

- PR title (under 70 chars, descriptive, starts with verb)
- Body (explains what changed and why)
- Test plan (includes verification steps)
- Links (references related issues, specs, discussions)
- Labels (appropriate labels applied)
- Draft state (draft if in progress, ready if complete)

### Commits (review-commits)

- Commit structure and atomicity
- Whether commits are focused and logical
- Commit granularity (not too large, not too fine-grained)

### Commit Messages (review-commit-messages)

- Message conventions (following project standards)
- Clarity (does it describe the change clearly?)
- Grammar and tone

### Diff (review-diff)

- Scope (does the diff match the stated goal?)
- Completeness (are all necessary changes included?)
- Coherence (do changes form a logical whole?)
- Reversibility (could this be cleanly reverted?)
- Side effects (no unrelated file changes)

### Code (review-code)

- Correctness (does code do what it claims?)
- Security (injection, auth, secrets, unsafe APIs)
- Performance (bottlenecks, N+1 queries, unnecessary copying)
- Maintainability (readability, understandability)
- Simplicity (unnecessary complexity?)
- Pattern match (follows existing codebase conventions)
- Error handling (errors caught, logged, surfaced appropriately)

## Workflow

```
User Request
    ↓
review-pr-contents → PR title/body/labels findings
    ↓
review-commits → Commit structure findings
    ↓
review-commit-messages → Message convention findings
    ↓
review-diff → Diff scope/completeness findings
    ↓
review-code → Code quality/pattern findings
    ↓
validate-review → Verify all findings are accurate
    ↓
post-review → Submit GitHub review with verdict
    ↓
[If issues found]
fix-review-findings → Address issues
    ↓
Re-run automated-code-review
```

## Review Verdicts

| Verdict           | When                                                    |
| ----------------- | ------------------------------------------------------- |
| `APPROVE`         | No outstanding issues, ready to merge                   |
| `COMMENT`         | Only P2 follow-ups remain (won't break if merged)       |
| `REQUEST_CHANGES` | Must fix before merge (security, correctness, breaking) |

## When to Use This Skill

- Comprehensive code review of a pull request
- Setting up automated review in new workflows
- Need detailed feedback across all review dimensions
- Want structured, repeatable review process

## When to Use `code-review` Instead

- Working with Henry's CI review bot workflow
- Need to trigger the automated CI review via labels
- Legacy workflow compatibility required

## Granular Skills Reference

This skill orchestrates these specialized review skills:

- **`scm-utils:review-pr-contents`** — Review PR metadata and presentation
- **`scm-utils:review-commits`** — Review commit structure and organization
- **`scm-utils:review-commit-messages`** — Review commit message conventions
- **`scm-utils:review-diff`** — Review diff scope and completeness
- **`scm-utils:review-code`** — Review code quality and correctness
- **`scm-utils:validate-review`** — Verify review findings are accurate
- **`scm-utils:post-review`** — Post the review on GitHub
- **`scm-utils:fix-review-findings`** — Address review findings

## External References

- [granular review skills](../../README.md) — Individual skill documentation
- [GitHub API review docs](https://docs.github.com/en/rest/pulls/reviews) — GitHub review API reference
- [Claude Code MCP tools](https://github.com/anthropics/claude-code-action#mcp-tools) — Available MCP tools for GitHub
