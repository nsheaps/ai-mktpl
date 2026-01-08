---
name: review-changes
description: Review code changes with detailed feedback, similar to CI code review
argument-hint: "[focus area or file pattern]"
allowed-tools: Bash(git:*), Bash(gh:*), Read, Glob, Grep, Edit, Write, Task, AskUserQuestion, TodoWrite
---

# Code Review

Review the current changes with detailed feedback on code quality, security, performance, and maintainability.

## Arguments

**Format:** `[focus area or file pattern]`

| Argument   | Required | Description                                      |
| ---------- | -------- | ------------------------------------------------ |
| focus area | No       | Specific aspect to focus on (e.g., "security")   |
| file pattern | No     | Specific files to review (e.g., "src/api/")      |

**Examples:**

- `/review-changes` - Review all uncommitted changes
- `/review-changes security` - Focus review on security aspects
- `/review-changes src/api/` - Review changes in specific directory
- `/review-changes performance src/utils/` - Focus on performance in utils

## Process

Execute the following steps using a sub-agent (Task tool with `general-purpose` type):

### Step 1: Gather Context

Collect information about the current state:

1. **Current branch**: `git branch --show-current`
2. **Git status**: `git status --short`
3. **Check for PR**: `gh pr view --json number,title,state,url,body 2>/dev/null`
4. **Get the diff**:
   - If PR exists: `gh pr diff`
   - If no PR: `git diff HEAD` or `git diff origin/main...HEAD`
5. **Recent commits**: `git log --oneline -10`

### Step 2: Create Review Tracking Document

Create a local document at `/tmp/review-notes-$(date +%s).md` to track:
- Summary of findings
- Specific comments with file:line references
- Questions or clarifications needed
- Links to relevant documentation

**CRITICAL:** Update this doc after reviewing each piece, since context is volatile.

### Step 3: Review the Changes

Evaluate the changes against these criteria:

#### Code Quality and Best Practices
- Is the code readable and self-documenting?
- Does it follow project conventions?
- Are there any code smells?

#### Potential Bugs or Issues
- Are edge cases handled?
- Is error handling appropriate?
- Are there race conditions or concurrency issues?

#### Performance Considerations
- Are there inefficient algorithms or data structures?
- Are there unnecessary operations or allocations?
- Could caching improve performance?

#### Security Concerns
- Are inputs validated and sanitized?
- Are there potential injection vulnerabilities?
- Are secrets handled properly?

#### Maintainability
- Is the code modular and testable?
- Are dependencies appropriate?
- Is the code complexity manageable?

#### Test Coverage
- Are there adequate tests for the changes?
- Do tests cover edge cases?

#### Documentation
- Are comments accurate and helpful?
- Is the PR description accurate vs code changes?

### Step 4: Apply Design Principles

Review against these principles:

**KISS** - Keep It Simple, Stupid!
Always aim for simplicity in designs and implementations.

**YAGNI** - You Aren't Gonna Need It!
Avoid adding features until they are absolutely necessary.

**DRY** - Don't Repeat Yourself!
Eliminate redundancy by reusing code and components.

**WET** - (Don't) Write Everything Twice!
Duplication is the enemy of maintainability; strive for single sources of truth.

**TDA** - Tell, Don't Ask!
Encapsulate logic within objects rather than querying for data externally.

**SOLID** - Follow SOLID principles:
- Single Responsibility/Separation of Concerns
- Open/Closed
- Liskov Substitution
- Interface Segregation
- Dependency Inversion

### Step 5: Generate Review Summary

Create a detailed review with:

1. **Overall assessment** - High-level summary of the changes
2. **Scores** (0-100%):
   - Quality score
   - Security score (or N/A if not applicable)
   - Simplicity score (if below 90%, suggest how to simplify)
   - Confidence score (how confident you are in assessment)
3. **Issues found** with file:line references
4. **Suggestions for improvement**

Use these indicators:
- ✅ Something correct or well-done
- ❔ Something requiring clarification
- ⚠️ Potential problem
- ❌ Definite problem that should be addressed

**Score Guidelines:**
- 85%+ = Green (good)
- 65-84% = Yellow (needs attention)
- Below 65% = Red (failure/must fix)

### Step 6: Ask User About Next Steps

After completing the review, use AskUserQuestion to ask:

**Question:** "Would you like me to address any of the issues found during this review?"

**Options** (based on issues found):
1. Fix critical issues (❌) - Address definite problems
2. Address warnings (⚠️) - Fix potential problems
3. Improve based on suggestions - Apply recommended changes
4. No changes needed - Review is complete

## Focus Area

If provided, focus the review on: $ARGUMENTS

When a focus area is specified:
- Prioritize reviewing aspects related to that area
- Still note other issues but don't deep-dive on them
- Organize findings by relevance to the focus area

## Review Output Format

```markdown
# Code Review Summary

## Overall Assessment
[1-2 sentence summary]

## Scores
| Metric     | Score | Notes |
|------------|-------|-------|
| Quality    | XX%   | ...   |
| Security   | XX%   | ...   |
| Simplicity | XX%   | ...   |
| Confidence | XX%   | ...   |

## Findings

### Critical Issues (❌)
- [file:line] Description of issue

### Warnings (⚠️)
- [file:line] Description of concern

### Questions (❔)
- [file:line] Clarification needed

### Positive Notes (✅)
- What was done well

## Suggestions
1. Specific improvement suggestion
2. ...
```

## Important Notes

- **Test after review:** If changes are made, re-run review to verify fixes
- **Iterative refinement:** Multiple review passes may be needed
- **Don't over-engineer:** Focus on real issues, not hypothetical ones
- **Trust the code:** Don't add unnecessary fallbacks or validation
