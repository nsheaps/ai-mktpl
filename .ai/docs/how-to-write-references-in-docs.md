# How to Write References in Documentation

This guide explains how to include external references in `.claude/` documentation files to ensure traceability and validation of claims.

## Why References Matter

1. **Traceability**: Future readers can verify claims and find original context
2. **Context preservation**: Conversations and decisions have full background
3. **Credibility**: Claims are backed by evidence, not just assertions
4. **Maintainability**: Outdated information can be identified and updated

## Reference Formats

### GitHub Links

```markdown
## References

- [PR #14797: Improve benchmark output](https://github.com/stainless-api/stainless/pull/14797)
- [Review comment on case sensitivity](https://github.com/stainless-api/stainless/pull/14797#discussion_r1234567890)
- [Issue #500: Performance regression](https://github.com/stainless-api/stainless/issues/500)
```

### Inline References

```markdown
The review bot suggested using case-insensitive comparison
([comment](https://github.com/org/repo/pull/123#discussion_r456)).
```

### Slack Permalinks

```markdown
Per the [architecture discussion](https://stainless.slack.com/archives/C123ABC/p1704825600123456),
we decided to use the factory pattern.
```

### Documentation Links

```markdown
This follows the [Claude Code configuration guide](https://docs.anthropic.com/claude-code/configuration).
```

### Stack Overflow / Forums

```markdown
The solution uses the approach from [this SO answer](https://stackoverflow.com/a/12345678)
which explains why `Object.keys()` preserves insertion order in modern JS.
```

### Raw Text Excerpts

When you cannot link to a source (e.g., private conversation, ephemeral context):

```markdown
> "We should suppress Read tool output to reduce noise in benchmark logs"
> -- Team discussion, 2024-01-09

Based on this feedback, the `TOOL_RESULT_SUPPRESSED` set was created.
```

## Placement Patterns

### Dedicated References Section

Best for documents with multiple sources:

```markdown
# Feature Plan

## Overview

...content...

## Implementation

...content...

## References

- [Original issue](https://github.com/...)
- [Design doc](https://docs.google.com/...)
- [Slack thread](https://workspace.slack.com/...)
```

### Inline with Context

Best for specific claims or decisions:

```markdown
## Decision

We chose Redis over Memcached because it supports data persistence
([benchmark comparison](https://example.com/redis-vs-memcached)).
```

### Footnote Style

For dense documents:

```markdown
The algorithm runs in O(n log n) time[^1].

[^1]: See [analysis](https://cs.example.edu/complexity/mergesort)
```

## What to Reference

| Content Type           | What to Link                              |
| ---------------------- | ----------------------------------------- |
| PR feedback prompts    | The actual PR review comments             |
| Bug fix plans          | The issue or bug report                   |
| Architecture decisions | Design docs, ADRs, discussion threads     |
| Performance claims     | Benchmark results, profiling data         |
| API usage              | Official documentation                    |
| Workarounds            | The issue being worked around             |
| Best practices         | Authoritative source (docs, style guides) |

## Getting GitHub Comment Links

1. On GitHub, find the comment you want to reference
2. Click the three-dot menu (...) on the comment
3. Select "Copy link"
4. The URL will look like: `https://github.com/org/repo/pull/123#discussion_r1234567890`

## Getting Slack Permalinks

1. Hover over the message
2. Click the three-dot menu (...)
3. Select "Copy link"
4. The URL will look like: `https://workspace.slack.com/archives/C123ABC/p1704825600123456`

## Minimum Requirements by Document Type

### Prompts (`.claude/prompts/`)

- Link to any PR, issue, or discussion being addressed
- Link to specific review comments if addressing feedback

### Plans (`.claude/plans/`)

- Link to requirements source (issue, spec, user request)
- Link to relevant prior art or examples

### Skills (`.claude/skills/`)

- Link to official documentation for tools/APIs
- Link to any non-obvious techniques used

### Scratch (`.claude/scratch/`)

- At minimum: Date and brief context
- Optional: Links to sources if doing research

## Example: PR Feedback Prompt

```markdown
# PR #14797 Review Feedback

## Source

- [PR #14797](https://github.com/stainless-api/stainless/pull/14797)
- Review by: stainless-review-bot

## Outstanding Items

### 1. Case sensitivity issue

**Location:** `packages/ai-config-helper/src/output-formatter.ts:21`
**Comment:** [Link to review comment](https://github.com/stainless-api/stainless/pull/14797#discussion_r...)

The bot noted that `TOOL_RESULT_SUPPRESSED` contains duplicate entries...
```
