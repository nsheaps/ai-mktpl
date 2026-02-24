---
name: review-changes
description: Review code changes with detailed feedback across multiple quality dimensions
argument-hint: "[--thorough] [focus area or file pattern]"
allowed-tools: Bash(git:*), Bash(gh:*), Read, Glob, Grep, Edit, Write, Task, AskUserQuestion, TodoWrite
---

# Code Review

Review the current changes with detailed feedback across multiple quality dimensions: simplicity, flexibility, usability, documentation, security, pattern adherence, best practices, and engineering quality.

## Arguments

**Format:** `[--thorough] [focus area or file pattern]`

| Argument     | Required | Description                                             |
| ------------ | -------- | ------------------------------------------------------- |
| `--thorough` | No       | Launch parallel per-category sub-agents for deep review |
| focus area   | No       | Specific aspect to focus on (e.g., "security")          |
| file pattern | No       | Specific files to review (e.g., "src/api/")             |

**Examples:**

- `/review-changes` — Quick review of all uncommitted changes
- `/review-changes --thorough` — Deep parallel review across all 8 categories
- `/review-changes security` — Focus review on security aspects
- `/review-changes --thorough src/api/` — Deep review of changes in specific directory
- `/review-changes performance src/utils/` — Focus on performance in utils

## Review Categories

All reviews evaluate these 8 dimensions. In default (quick) mode, a single agent covers all. In `--thorough` mode, each gets a dedicated parallel sub-agent.

### 1. Simplicity

Is the code as simple as it can be while still correct? Unnecessary complexity, over-engineering, functions doing too many things, overly clever code, unnecessary abstractions, cyclomatic complexity.

### 2. Flexibility

How well does this code adapt to different use cases? Hardcoded values that should be configurable, missing inputs, assumptions about structure, edge case handling, extensibility, feature completeness, sensible defaults.

### 3. Usability

How easy is it for a developer to use? Input/API name clarity, error message quality, required vs optional clarity, sensible defaults, output usefulness, logging quality, discoverability, first-use experience.

### 4. Documentation & Comments (with Discoverability)

Is the code well-documented and discoverable? Inline comments (WHY not WHAT), function-level docs, README completeness, usage examples (realistic and copy-pasteable), input descriptions, consistency between docs and behavior. Are things findable?

### 5. Security

Are there vulnerabilities or risks? Secret handling, input injection, URL validation, credential leakage, API auth security, shell injection, dependency security, OWASP top 10 where applicable.

### 6. Pattern Matching

Does the PR match existing repo patterns or properly introduce new ones? File structure conventions, language/framework conventions, project-specific conventions, README format consistency, commit message format. Are new patterns improvements or unintentional deviations?

### 7. Best Practices

Industry best practices adherence? Language-specific conventions (shellcheck, linting, quoting, error handling), framework conventions, API integration (retry logic, timeouts, idempotency), git (conventional commits), defensive coding, observability.

### 8. Quality Assurance & Engineering

Is the engineering sound? Correctness, edge cases, error handling, race conditions, resource leaks, testability, code smell, regression risk, missing validation at boundaries.

## Process

Execute the following steps using a sub-agent (Task tool with `general-purpose` type):

### Step 1: Gather Context

Collect information about the current state:

1. **Current branch**: `git branch --show-current`
2. **Git status**: `git status --short`
3. **Check for PR**: `gh pr view --json number,title,state,url,body,baseRefName 2>/dev/null`
4. **Get the diff**:
   - If PR exists: `gh pr diff`
   - If no PR: `git diff HEAD` or `git diff origin/main...HEAD`
5. **Recent commits**: `git log --oneline -10`
6. **Commit history relation to base branch**: `git log --oneline $(git merge-base HEAD origin/main)..HEAD`
7. **PR title and body**: Extract from step 3 — these are review inputs, not just metadata
8. **Commit messages**: `git log --format="%h %s" $(git merge-base HEAD origin/main)..HEAD`

### Step 2: Determine Output Location

Determine where to save review artifacts:

- **In a repo with a PR**: `.claude/pr-reviews/$org/$repo/$prNumber/$epochTime/`
- **In a repo without a PR**: `.claude/pr-reviews/$org/$repo/local/$epochTime/`
- **Outside a repo**: `/tmp/review-notes-$epochTime.md` (fallback only)

The epoch timestamp (`date +%s`) ensures each review run is unique and comparable to previous runs.

### Step 3: Review the Changes

#### Quick Mode (default)

Evaluate the changes against all 8 categories in a single pass. Create a consolidated review document.

#### Thorough Mode (`--thorough`)

Launch 8 parallel sub-agents (`run_in_background: true` Task tool), one per category. Each agent:

1. Receives the full diff, commit history, PR metadata, and its specific category criteria
2. Evaluates the changes ONLY through its category lens
3. Scores the category 0-100
4. Writes findings to `$outputDir/$category/REPORT.md`
5. May identify inline comments to post

After all 8 complete, compile the overall report.

**All findings must cite evidence** — file paths with line numbers, links to external documentation, references to other files in the codebase or org repos, relevant standards or specifications. Unsupported claims are not actionable.

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
2. **Score table** with emoji-coded indicators (see Scoring System below)
3. **Executive summary** with Critical/Important/Well-Done sections
4. **Issues found** with file:line references and severity ratings
5. **Suggestions for improvement**
6. **Links to individual category reports** (thorough mode)

### Step 6: Post Review or Present Results

**Detect execution context and route output accordingly:**

#### Agentic Mode (can post to GitHub)

If you have `gh` access and the PR exists:

1. **Manage previous iterations** (see Review Lifecycle Management):
   - Resolve old inline comments where the underlying finding has been fixed
   - Dismiss previous automated review iterations with "Superseded by review vN"
   - Never resolve or dismiss human reviewer comments
2. Post inline comments for significant findings as individual comment-only reviews
   - Include the finding code (e.g., `C1`, `M3`) for cross-referencing with the overall report
   - Prefix each with category: `**Security [C1]**: [comment]`, `**Simplicity [M3]**: [comment]`
   - Use 🔕 prefix for non-blocking comments
   - Use ℹ️ prefix for info-only comments (validated/checked items)
3. Post a final review with the compiled overall assessment
   - Use `<details><summary>` elements for collapsible detail sections
   - Use shields.io badges for visual score display (see Output Format)
   - If overall > 95%, keep the final review to just the score table

#### Interactive CLI Mode

Provide file paths to the saved reports so the user can open them:

- Link to local report files
- Link to files on GitHub if on a pushed branch
- Offer to open specific reports

### Step 7: Ask User About Next Steps

After completing the review, use AskUserQuestion to ask:

**Question:** "Would you like me to address any of the issues found during this review?"

**Options** (based on issues found):

1. Fix critical issues (🚨) - Address definite problems
2. Address warnings (⚠️) - Fix potential problems
3. Improve based on suggestions - Apply recommended changes
4. No changes needed - Review is complete

## Scoring System

Each category scored 0-100:

| Range  | Rating               | Indicator               |
| ------ | -------------------- | ----------------------- |
| 90-100 | Exceptional          | ✅ `:white_check_mark:` |
| 85-89  | Good                 | ✅ `:white_check_mark:` |
| 70-84  | Adequate, needs work | ⚠️ `:warning:`          |
| 60-69  | Notable issues       | 🚨 `:rotating_light:`   |
| < 60   | Significant problems | 🚨 `:rotating_light:`   |

**Cap rule**: If ⚠️ appears in ANY category, the maximum overall score is 94% — a PR cannot be "green" overall while any individual dimension needs attention.

**Brevity rule**: If the overall score is > 95%, keep the final review to just the score table. Excellent PRs don't need verbose explanations.

**Overall score**: Weighted average of category scores. Weight each category equally unless the focus area argument shifts emphasis.

## Per-Category Report Format

Each category report (in thorough mode) follows this structure:

```markdown
# {Category} Review — Score: XX/100

[Opening paragraph explaining the score — what drives it up or down]

## Detailed Findings

### [Finding Title]

[Description with file:line references]

**Severity**: Critical | High | Medium | Low
**References**: [links to docs, other files, standards]

### [Next Finding]

...

## Comparison Summary (if applicable)

[Table comparing this code against similar code in the repo or org]

## References

- [file:line] — Description
- [external link] — Why it's relevant
```

## Overall Report Format

```markdown
# Overall PR Review: [PR Title]

## Score Summary

| Category          | Score      | Status  |
| ----------------- | ---------- | ------- |
| Simplicity        | XX/100     | [emoji] |
| Flexibility       | XX/100     | [emoji] |
| Usability         | XX/100     | [emoji] |
| Documentation     | XX/100     | [emoji] |
| Security          | XX/100     | [emoji] |
| Patterns          | XX/100     | [emoji] |
| Best Practices    | XX/100     | [emoji] |
| Quality Assurance | XX/100     | [emoji] |
| **Overall**       | **XX/100** | [emoji] |

## Executive Summary

[2-3 paragraph summary]

### Critical Issues (Must Fix)

1. **[Category]: [Issue]** (`file:line`) — [Description]

### Important Issues (Should Fix)

1. **[Category]: [Issue]** (`file:line`) — [Description]

### What's Done Well

- [Positive finding with specific reference]

## Detailed Category Reports

- [Simplicity](./simplicity/REPORT.md)
- [Flexibility](./flexibility/REPORT.md)
- ...
```

## GitHub PR Review Format

When posting to GitHub as a PR review:

```markdown
# PR Review: [Title]

![Simplicity](https://img.shields.io/badge/Simplicity-XX%25-color)
![Flexibility](https://img.shields.io/badge/Flexibility-XX%25-color)
![Usability](https://img.shields.io/badge/Usability-XX%25-color)
![Documentation](https://img.shields.io/badge/Documentation-XX%25-color)
![Security](https://img.shields.io/badge/Security-XX%25-color)
![Patterns](https://img.shields.io/badge/Patterns-XX%25-color)
![Best Practices](https://img.shields.io/badge/Best_Practices-XX%25-color)
![QA](https://img.shields.io/badge/QA-XX%25-color)
![Overall](https://img.shields.io/badge/Overall-XX%25-color)

[Score table]

<details>
<summary>Executive Summary</summary>

[Full executive summary]

</details>

<details>
<summary>Critical Issues (X found)</summary>

[Critical issues list]

</details>

<details>
<summary>Important Issues (X found)</summary>

[Important issues list]

</details>

<details>
<summary>What's Done Well</summary>

[Positive findings]

</details>
```

**Badge colors** (shields.io):

- Score >= 85: `brightgreen`
- Score 70-84: `yellow`
- Score < 70: `red`

**URL format**: `https://img.shields.io/badge/{label}-{score}%25-{color}`

- Spaces in labels become underscores: `Best_Practices`

## Finding Codes

Each finding in inline comments gets a unique code for cross-referencing between the overall report and individual comments. The format is `{severity}{sequence}`:

| Prefix | Severity | Description                                |
| ------ | -------- | ------------------------------------------ |
| `C`    | Critical | Must fix before merge                      |
| `H`    | High     | Should fix before merge                    |
| `M`    | Medium   | Improve if possible, acceptable to defer   |
| `N`    | Note     | Nice-to-have, informational, or suggestion |

**Examples**: `C1` (first critical finding), `M3` (third medium finding), `N2` (second note)

Finding codes are stable within a review iteration. They appear in both the overall report and inline comments so reviewers can cross-reference. When a finding is resolved in a subsequent iteration, reference the original code: "C1 from v2 — resolved."

## Inline Comment Prefixes

When posting inline PR comments:

| Prefix | Meaning                                         |
| ------ | ----------------------------------------------- |
| (none) | Blocking issue — should be fixed before merge   |
| 🔕     | Non-blocking — nice to fix but not required     |
| ℹ️     | Info only — validated/checked, no action needed |

Limit "additional validation" info comments unless they cover mission-critical items. Sub-agent reference docs should still track them verbosely.

## Review Lifecycle Management

When posting iterative reviews on the same PR (v2, v3, etc.), manage the review timeline to keep it clean and actionable.

### Resolve Old Inline Comments

When posting a new review iteration, check each previous inline comment:

1. **Read the old comment's finding** — what was the issue?
2. **Check the current code at that location** — is the issue still present?
3. **If fixed**: Resolve/hide the old comment. Optionally add a reply: "Resolved in [commit hash]"
4. **If still present**: Leave the comment open. Do NOT resolve comments for findings that haven't been addressed.

**Implementation** (GitHub API via `gh`):

```bash
# List review comments on a PR
gh api repos/{owner}/{repo}/pulls/{pr}/comments --jq '.[] | {id, path, body, line}'

# Resolve a comment thread (minimize/hide)
gh api graphql -f query='mutation { minimizeComment(input: {subjectId: "<node_id>", classifier: OUTDATED}) { minimizedComment { isMinimized } } }'
```

**Rules:**

- Only resolve comments from YOUR previous review iterations (identified by the bot user or review format)
- Never resolve comments from human reviewers
- When in doubt, leave the comment open

### Dismiss Previous Review Iterations

When posting a v3 review, dismiss the v2 review to reduce timeline noise:

```bash
# List reviews on a PR
gh api repos/{owner}/{repo}/pulls/{pr}/reviews --jq '.[] | {id, state, body}'

# Dismiss a previous review
gh api repos/{owner}/{repo}/pulls/{pr}/reviews/{review_id}/dismissals -f message="Superseded by review v3" -f event="DISMISS"
```

**Rules:**

- Only dismiss YOUR previous automated reviews (match by format/author)
- Never dismiss human reviews
- Include a clear dismissal message: "Superseded by review vN"
- The dismissed review remains visible (collapsed) in the timeline — it's not deleted

## Focus Area

If provided, focus the review on: $ARGUMENTS

When a focus area is specified:

- Prioritize reviewing aspects related to that area
- Still note other issues but don't deep-dive on them
- Organize findings by relevance to the focus area

## Important Notes

- **Test after review:** If changes are made, re-run review to verify fixes
- **Iterative refinement:** Multiple review passes may be needed
- **Don't over-engineer:** Focus on real issues, not hypothetical ones
- **Trust the code:** Don't add unnecessary fallbacks or validation
- **Evidence-based:** All findings should cite specific file:line references, external docs, or org standards. Unsupported claims are noise.
- **Incremental reviews:** Previous review results (in `.claude/pr-reviews/`) enable comparison across review runs
