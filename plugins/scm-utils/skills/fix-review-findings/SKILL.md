---
name: fix-review-findings
description: >
  Fix issues found during a review. Use when asked to "fix review findings",
  "address review comments", "fix the issues found", or after a review
  identifies problems that need code changes.
argument-hint: "[review report path or PR number]"
---

# Fix Review Findings

Address issues identified during a code review, working through findings systematically.

## Process

1. **Read the review report** or PR review comments to understand all findings
2. **Triage findings** by priority:
   - P0 (critical: security, correctness) -- fix first
   - P1 (important: maintainability, patterns) -- fix next
   - P2 (nice-to-have: style, minor improvements) -- fix if time permits
3. **Fix each finding**:
   - Make the smallest change that addresses the issue
   - Do not introduce new scope while fixing
   - Commit fixes in logical groups (not one giant commit)
4. **Validate fixes**:
   - Use `scm-utils:validate-review` to confirm findings are resolved
   - Run tests to ensure fixes don't break anything
5. **Update the review report** if one exists, marking findings as resolved

## Anti-Patterns

| Bad                                 | Good                                  |
| ----------------------------------- | ------------------------------------- |
| Fix everything in one huge commit   | Group fixes logically                 |
| Add new features while fixing       | Fix only what was found               |
| Skip validation after fixing        | Re-run review to confirm resolution   |
| Dismiss findings without addressing | Address or explain why not applicable |
