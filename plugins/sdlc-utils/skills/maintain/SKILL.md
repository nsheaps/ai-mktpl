---
name: maintain
description: >
  Maintenance, bug fixes, and technical debt management. Use when the user asks
  about "bug fix", "tech debt", "refactoring", "maintenance", "deprecation",
  "migration", "upgrade dependencies", or when managing ongoing codebase health.
  Covers bug triage, refactoring strategy, and dependency management.
---

# Maintenance

Guidelines for maintaining software after initial deployment.

## Bug Fix Workflow

### Step 1: Reproduce

- Reproduce the bug locally before attempting a fix
- Document exact reproduction steps
- Identify the root cause (not just the symptom)

### Step 2: Fix

- Write a regression test first (that fails with the bug)
- Apply the minimal fix that addresses the root cause
- Search the codebase for the same pattern elsewhere
- Fix ALL instances, not just the one reported

### Step 3: Verify

- Confirm the regression test now passes
- Run the full test suite
- Verify the fix in the same environment where the bug was found

## Refactoring Strategy

- Refactor in small, focused PRs
- Separate refactoring from feature work (never mix)
- Ensure existing tests pass before and after
- Move first, improve later (see incremental operations pattern)

## Technical Debt Management

- Track tech debt as issues with clear descriptions
- Prioritize based on impact (blocking future work > cosmetic)
- Address during maintenance windows, not during feature sprints
- Document why shortcuts were taken and when to fix them

## Dependency Management

- Update dependencies regularly (not just when forced)
- Review changelogs before upgrading
- Run full test suite after any dependency change
- Pin versions in production; use ranges only in libraries

## Anti-Patterns

| Anti-Pattern               | Instead                                       |
| -------------------------- | --------------------------------------------- |
| Fixing symptoms only       | Find and fix root causes                      |
| Mixing refactor + feature  | Separate into distinct PRs                    |
| Ignoring tech debt         | Track and prioritize it                       |
| Upgrading without testing  | Always run full test suite after upgrades     |
| One-off bug fixes          | Search for the same pattern across codebase   |
