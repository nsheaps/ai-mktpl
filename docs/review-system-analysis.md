# Review System Analysis Report

**Date:** 2026-03-24
**Repository:** nsheaps/ai-mktpl
**Scope:** Complete analysis of the automated PR review system

---

## Executive Summary

The ai-mktpl review system is a multi-layered automated PR review pipeline built on `claude-code-action`, GitHub Apps, and a plugin-based skill architecture. It uses Claude Opus as the review model, posts structured reviews via GitHub's native review API, and supports both CI-triggered and interactive review modes. The system is sophisticated but has architectural debt from organic growth — the review logic exists in three overlapping locations with different levels of refinement.

---

## 1. Architecture Overview

### Components

| Component | Location | Purpose |
|-----------|----------|---------|
| **CI Workflow** | `.github/workflows/claude-code-review.yaml` | GitHub Actions workflow triggered on PR events |
| **Review Prompt** | `.github/prompts/claude-code-review.md` | Detailed prompt template for CI review bot |
| **Shared Self-Review Skill** | `shared/skills/self-review/SKILL.md` | Multi-agent review procedure (scoring, dimensions, format) |
| **Plugin Code-Review Skill** | `plugins/scm-utils/skills/code-review/SKILL.md` | Entry point: triggers CI or falls back to self-review |
| **Plugin Template** | `plugins/scm-utils/skills/code-review/references/prompt-template.md` | Prompt template for other repos |
| **Workflow Template** | `plugins/scm-utils/skills/code-review/references/workflow-template.yaml` | Workflow template for other repos |
| **Interpolation Action** | `.github/actions/interpolate-prompt/action.yml` | `envsubst`-based template interpolation |
| **Agent Trigger** | `.github/workflows/claude-agent-trigger.yaml` | Detects @claude mentions, dispatches to agent |
| **Agent Workflow** | `.github/workflows/claude-agent.yaml` | Handles repository_dispatch from @claude mentions |

### Flow: CI-Triggered Review

```
PR Event (open/sync/ready_for_review/labeled)
  │
  ├─ Condition Check: not draft, OR 'request-review' label
  │
  ├─ Checkout as GitHub App (nsheaps/github-actions/checkout-as-app)
  │
  ├─ Remove 'request-review' label (if applicable)
  │
  ├─ Get job context (qoomon/actions--context)
  │
  ├─ Install gh-pr-review extension (for review comment access)
  │
  ├─ Interpolate prompt template (envsubst with REPO, PR_NUMBER, JOB_CONTEXT)
  │
  └─ Run claude-code-action@v1
       ├─ Model: opus
       ├─ Auth: GitHub App token
       ├─ MCP Tools: github__get_pull_request*, github__*_review*
       ├─ Bash Tools: git, gh (read-only)
       ├─ Denied: CI status checks, git push
       └─ Posts: Pending review → inline comments → submit review
```

### Flow: Interactive Review (Shared Self-Review Skill)

```
User invokes /code-review or /self-review
  │
  ├─ code-review checks for CI workflow → triggers via label if available
  │
  └─ Falls back to self-review skill:
      ├─ Launches 8 background sub-agents (one per review category)
      │   ├─ Simplicity      ├─ Security
      │   ├─ Flexibility     ├─ Patterns
      │   ├─ Usability       ├─ Best Practices
      │   ├─ Documentation   └─ QA/Engineering
      │
      ├─ Each agent writes REPORT.md to .claude/pr-reviews/...
      │
      └─ Parent agent synthesizes into final review with score table
```

---

## 2. Strengths

### 2.1 Structured Review Process
The 11-step review process in the CI prompt is well-thought-out. It enforces:
- Local doc tracking (compensates for context window volatility)
- Previous review management (minimize, resolve, update)
- Post-review verification
- Clear verdict criteria

### 2.2 GitHub Integration Depth
The system leverages GitHub's full review API surface:
- Pending reviews with inline comments (not just PR comments)
- GraphQL for minimizing comments and resolving threads
- `gh-pr-review` extension for better review comment access
- Proper bot identity management (`bot_id`, `bot_name`, `allowed_bots`)

### 2.3 Concurrency Safety
The workflow uses `cancel-in-progress: false` with PR-scoped concurrency groups, preventing review waste while avoiding stale reviews from racing.

### 2.4 Flexible Trigger System
Supports multiple trigger patterns:
- Automatic on non-draft PR open/sync
- Manual via `request-review` label (auto-removed)
- Persistent via `always-review` label for drafts

### 2.5 Security Consciousness
- Git push denied in CI context
- CI status checks denied (prevents self-referential loop)
- GitHub App auth (not PAT) for proper identity
- Separate secrets for review vs general CI

### 2.6 Distributable via Plugin
The scm-utils plugin packages the review system for reuse across repos with templates, setup guide, and clear secret requirements.

---

## 3. Weaknesses

### 3.1 Review Logic Split (Improved in v2)
Previously, review instructions existed in three divergent places. In v2, the architecture was restructured:

| Location | Purpose | Status |
|----------|---------|--------|
| `.github/prompts/claude-code-review.md` | Active CI prompt (comprehensive) | Updated with fixes |
| `plugins/scm-utils/.../prompt-template.md` | Template for other repos | Updated with fixes |
| `shared/skills/self-review/SKILL.md` | Shared review procedure | **NEW** — extracted from project skill |
| `.claude/skills/code-review/SKILL.md` | (Removed) | **REMOVED** — replaced by shared skills |

The CI prompt and plugin template still need to be kept in sync manually. A future improvement could generate both from a single source.

### 3.2 Single-Agent CI Review Bottleneck
The CI workflow runs a single Claude session. For large PRs, this means:
- Long review times (often 10-20+ minutes)
- Risk of context window exhaustion on complex changes
- No parallelism for independent review concerns (security vs. quality vs. patterns)

The project-level SKILL.md already describes a multi-agent approach, but this architecture hasn't been brought to the CI workflow.

### 3.3 No Structured Output Validation
The review output format (badges, details/summary, footnotes) relies entirely on prompt instructions. There's no post-processing to validate that the output is well-formed markdown before posting. This has led to issues like CDATA wrappers appearing in posted reviews.

### 3.4 COMMENT Verdict Overuse
The original guidance made it too easy to use `COMMENT` (non-blocking) when `REQUEST_CHANGES` would be more appropriate. The threshold was "won't break if merged" rather than "would the code be better if this were addressed." This resulted in reviews that identified real improvements but didn't enforce them.

### 3.5 Template Synchronization Problem
The `interpolate-prompt` action uses `envsubst`, which means the prompt template is a flat markdown file with `${VAR}` placeholders. There's no mechanism to:
- Share common sections between the CI prompt and scm-utils template
- Version the prompt independently from the workflow
- Test prompt changes before deploying

### 3.6 Missing Review State Persistence
The CI review runs in a fresh environment every time. While the prompt instructs the agent to review previous reviews, there's no persistent memory of past review decisions. Each review re-evaluates from scratch, which can lead to:
- Score inconsistency across reviews
- Re-raising issues that were already discussed and resolved
- Missing context from conversations that happened between reviews

### 3.7 No Inline Comment Deduplication
The prompt says "future reviews don't need to re-post in-line comments" but there's no mechanism to enforce this. The agent must discover its previous inline comments via API calls during the review, adding complexity and unreliability.

---

## 4. How the Pieces Fit Together

### scm-utils (Plugin) vs. ai-mktpl (Project)

| Aspect | scm-utils Plugin | ai-mktpl Project |
|--------|-----------------|------------------|
| **Purpose** | Distributable review setup for any repo | This repo's specific review instance |
| **Skill** | `code-review` — triggers CI or falls back to local review | `code-review` — multi-agent local review |
| **Prompt** | Template for new repos | Active CI prompt |
| **Workflow** | Template for new repos | Active CI workflow |
| **Audience** | Plugin consumers (other repos) | ai-mktpl itself |

The scm-utils plugin is the **distribution mechanism**. It contains templates and a skill that knows how to trigger the CI bot (via label) or fall back to local review. The ai-mktpl project has its own instantiated copies that have evolved beyond the templates.

### Self-Review vs. CI Review

- **Self-review** (`shared/skills/self-review/SKILL.md`): Multi-agent review procedure using background sub-agents. Used as fallback when CI isn't available, or invoked directly.
- **CI review** (`.github/workflows/claude-code-review.yaml`): Automated, runs on PR events, posts as a GitHub App. Uses a single Claude session with the CI prompt. Primary review mechanism.
- **Code-review entry point** (`plugins/scm-utils/skills/code-review/`): User-facing skill that routes to CI (preferred) or self-review (fallback).

---

## 5. Known Improvements

The following improvements are tracked as GitHub issues:

- Unify CI prompt and plugin template from a single source (high priority)
- Add output validation gate for review markdown
- Multi-agent CI review via Agent Teams (when feature exits experimental)

See the [ai-mktpl issues](https://github.com/nsheaps/ai-mktpl/issues?q=label%3Areview-system) for current status.
