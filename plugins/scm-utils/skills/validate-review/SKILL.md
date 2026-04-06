---
name: validate-review
description: >
  Validate that review findings are accurate and actionable. Use when asked to
  "validate review", "check if review findings are correct", "verify review
  accuracy", or when confirming that a review's claims match actual code state.
argument-hint: "[review report path or PR number]"
---

# Validate Review

Confirm that review findings are accurate, not false positives, and actionable.

## Process

1. **Read each finding** from the review
2. **Verify against actual code**: Does the issue actually exist at the referenced location?
3. **Check context**: Is the reviewer missing context that explains the pattern?
4. **Classify each finding**:
   - Confirmed: issue exists as described
   - False positive: issue does not exist or is already handled
   - Needs context: finding is technically correct but justified by design
5. **Report** which findings are valid, which are not, and why

## When to Use

- Before spending time fixing review findings, validate them first
- When a review seems overly harsh or many findings feel wrong
- After an automated review (bots may miss context humans would catch)
- When review findings conflict with each other

## Output

- Per-finding validation status (confirmed, false positive, needs context)
- Evidence for each determination (code references, design docs)
- Recommended action for each finding
