---
name: review
description: >
  Code review practices and quality checks. Use when the user asks to "review
  code", "review a PR", "code review", "check code quality", "review changes",
  "score this code", or when evaluating code for merge readiness. Covers
  review checklists, scoring criteria, feedback conventions, and iterative
  improvement until quality thresholds are met.
---

# Code Review

Structured code review for evaluating and improving code quality before merge.

## Review Categories

Evaluate code across these dimensions, scoring each 0-100:

| Category          | What to check                                     |
| ----------------- | ------------------------------------------------- |
| Simplicity        | Is the code as simple as it can be?               |
| Correctness       | Does it do what the spec says?                    |
| Security          | Are there vulnerabilities or unsafe patterns?     |
| Performance       | Are there obvious performance issues?             |
| Maintainability   | Can someone else understand and modify this?      |
| Pattern adherence | Does it follow existing codebase conventions?     |
| Test coverage     | Are changes covered by tests?                     |
| Documentation     | Are public APIs and non-obvious logic documented? |

## Score Thresholds

| Score  | Status | Meaning                     |
| ------ | ------ | --------------------------- |
| >= 85% | Pass   | Ready to merge              |
| 70-84% | Warn   | Should address before merge |
| < 70%  | Block  | Must address before merge   |

## Review Workflow

### Step 1: Understand Context

- Read the PR description and linked spec/issue
- Understand what the code is supposed to do
- Check the full diff against the base branch (not just latest commit)

### Step 2: Review

For each category:

1. Examine the relevant code
2. Note specific findings with file and line references
3. Assign a score
4. Provide actionable feedback for anything below 85%

### Step 3: Provide Feedback

- Be specific: reference exact lines and files
- Be actionable: say what to change, not just what is wrong
- Assign priority levels to all findings: P0 (critical), P1 (important), P2 (nice-to-have)
- All findings must be listed — none should be silently dismissed

### Step 4: Iterate

If scores are below threshold, the author addresses feedback and requests
re-review. Repeat until all categories pass.

## Verdicts

| Verdict         | When                                              |
| --------------- | ------------------------------------------------- |
| Approve         | All categories >= 85%, no P0 or P1 issues         |
| Comment         | Only P2 follow-ups remain                         |
| Request Changes | Any category < 70% or security/correctness issues |

## Anti-Patterns

| Anti-Pattern            | Instead                                    |
| ----------------------- | ------------------------------------------ |
| Rubber-stamping         | Actually read and evaluate the code        |
| Nitpicking style only   | Focus on substance (correctness, security) |
| Vague feedback          | Give specific, actionable comments         |
| Reviewing only the diff | Understand the full context                |

## External References

- [Google Engineering Practices: Code Review](https://google.github.io/eng-practices/review/)
- [Conventional Comments](https://conventionalcomments.org/)
