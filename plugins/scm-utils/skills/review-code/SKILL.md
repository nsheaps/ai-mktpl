---
name: review-code
description: >
  Review code quality, patterns, and bugs. Use when asked to "review the code",
  "check code quality", "look for bugs", "review implementation", or when
  evaluating code correctness, security, and maintainability independent of
  the diff or PR context.
argument-hint: "[file path, directory, or PR number to scope the review]"
---

# Review Code

Evaluate the code itself for quality, correctness, and adherence to best practices.

## What to Evaluate

| Dimension       | Check for                                              |
| --------------- | ------------------------------------------------------ |
| Correctness     | Does the code do what it claims? Edge cases handled?   |
| Security        | Injection, auth issues, secrets exposure, unsafe APIs  |
| Performance     | Obvious bottlenecks, N+1 queries, unnecessary copying  |
| Maintainability | Readable? Can someone else modify it in 6 months?      |
| Simplicity      | Is there unnecessary complexity? Could it be simpler?  |
| Pattern match   | Does it follow existing codebase conventions?          |
| Error handling  | Are errors caught, logged, and surfaced appropriately? |

## Process

1. Read the code under review (files, functions, modules)
2. Identify the existing patterns in the codebase for comparison
3. For each dimension, note specific findings with file:line references
4. Score each dimension 0-100
5. Provide actionable feedback for anything below 85%

## Output

- Specific findings with file and line references
- Score per dimension
- Actionable suggestions (what to change, not just what is wrong)
- Assign priority levels: P0 (critical), P1 (important), P2 (nice-to-have)

## References

- [Google Engineering Practices: What to Look For](https://google.github.io/eng-practices/review/reviewer/looking-for.html)
