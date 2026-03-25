---
name: self-review
description: >
  Self-review code changes before committing or submitting. Triggers on "self-review",
  "review my changes", "check my code", "review before commit", "quality check",
  or when the agent wants to validate code quality before finalizing work.
  Also invoked by the CI code-review workflow for structured multi-agent review.
argument-hint: [PR number | branch name | --staged]
---

# Self-Review — Multi-Agent Code Quality Evaluation

A structured self-review process that evaluates code changes across multiple quality dimensions using parallel sub-agents. Produces a scored report with inline PR comments and a synthesized summary.

## Review Dimensions

Each dimension is evaluated independently by a background sub-agent:

| Dimension | What It Evaluates |
|-----------|-------------------|
| **Simplicity** | KISS, YAGNI — is the solution as simple as it can be? |
| **Flexibility** | Open/Closed, extensibility without modification |
| **Usability** | API ergonomics, developer experience, discoverability |
| **Documentation** | Comments, docstrings, PR description accuracy, discoverability |
| **Security** | Input validation, auth, secrets handling, OWASP concerns |
| **Patterns** | Adherence to existing repo patterns, proper introduction of new ones |
| **Best Practices** | SOLID, DRY, WET, TDA, error handling, testing |
| **QA/Engineering** | Test coverage, edge cases, reliability, CI considerations |

## How It Works

### Step 1: Gather Context

Factor in all available context:
- PR title and body, commit messages, commit history
- The commit history's relation to its base branch
- Existing repo patterns and conventions
- Repository documentation (AGENTS.md, CLAUDE.md, README.md, .claude/rules/)

### Step 2: Launch Parallel Sub-Agents

Launch a `run_in_background:true` Task sub-agent (do NOT launch Teammates) for each review dimension. Each agent independently evaluates the change in its category and produces:
- A score from 0-100
- A short paragraph explaining the score
- Many references to support claims (codebase links, external docs, org repos, wikis, workflow links)

Each agent writes its report to:
```
.claude/pr-reviews/$org/$repo/$prNumber/$epochTime/$category/REPORT.md
```

Each agent may also:
- Leave inline comments to be posted on the PR
- Write additional supporting documentation referenced from their REPORT.md

### Step 3: Synthesize Results

When all agents complete, review each report. Compare results across dimensions to build a complete picture. Create one overall report including:

- Score table with emoji indicators:
  - 🚨 Score below 70%
  - ⚠️ Score below 85%
  - ✅ Score 85% or above
- If any category has ⚠️, the overall score should reflect that no category achieved ✅ level
- If overall score is >95%, the detailed section can be minimal (just the table and a brief summary)
- References from sub-agents should be verbose and verifiable

### Step 4: Post Review

**In agentic mode** (CI or empowered session):
- Leave inline comments as individual comment-only reviews
- Post a final review at the end with a `<details>/<summary>` block
- Use shields.io badges for concise score visualization (color-matched to emoji thresholds)
- Future reviews don't need to re-post existing inline comments

**In interactive CLI mode:**
- Provide links to files on GitHub or locally so the user can review themselves

## Review Verdict Criteria

Use **REQUEST_CHANGES** when:
- Security, performance, or correctness issues must be fixed before merging
- The code would improve meaningfully from a suggested change and the change is straightforward to make
- If a change would make the code better and it's reasonable to do before merge, it IS a requested change

Use **APPROVE** when:
- The PR is ready to merge as-is with no outstanding issues

Use **COMMENT** only when ALL of these are true:
- The code won't break if merged as-is
- The suggestions are genuinely optional and there is a clear reason why each should NOT be addressed in this PR
- If a suggestion would improve the code and is reasonable to implement, use REQUEST_CHANGES instead

**The bar for non-blocking feedback:**
The goal is to merge high-quality code. If feedback would improve the code, and the improvement is within scope and straightforward, it IS blocking. Non-blocking items must justify why they shouldn't be addressed now.

## Inline Comment Conventions

- ℹ️ — Info only (validated/checked items)
- 🔕 — Non-blocking (MUST include justification for why it's not blocking)
- No prefix — Blocking (must be addressed before merge)

## Output Formatting

CRITICAL: NEVER wrap any output in `<![CDATA[...]]>` tags. All output must be plain GitHub-flavored markdown.

Use `<details>/<summary>` for collapsible sections. Use shields.io badges for scores:
```
https://img.shields.io/badge/<SCORE>-%20?style=for-the-badge&label=<LABEL>&labelColor=%23444&color=<COLOR>
```

Colors: Green `#60A060` (85+), Yellow `#C0C040` (65-84), Red `#D07070` (<65), Gray `#444444` (N/A)

## Design Principles

Code changes should follow:
- **KISS** — Keep It Simple, Stupid
- **YAGNI** — You Aren't Gonna Need It
- **DRY** — Don't Repeat Yourself
- **WET** — (Don't) Write Everything Twice
- **TDA** — Tell, Don't Ask
- **SOLID** — Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion
