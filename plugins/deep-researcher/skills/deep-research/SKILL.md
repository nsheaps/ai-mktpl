---
name: deep-research
description: |
  Use this skill when investigating undocumented behavior, internal mechanisms, or "how does X work?" questions where official documentation is insufficient.
  Trigger when:
  - External docs/issues don't explain the full mechanism
  - You need to trace how a feature actually works at the code level
  - Previous research findings need source-level verification
  - You're investigating behavior differences between documented and observed behavior
---

# Deep Research Methodology

A repeatable playbook for investigating undocumented mechanisms, internal behaviors, and "how does X work?" questions.

## When to Use Agents for Research

For complex, multi-source investigations, **use the deep-researcher agent** rather than doing research inline. The agent is purpose-built for this:

```
# Spawn a research agent for complex investigations
Agent(deep-researcher, "Investigate how Claude Code sets terminal tab titles — check source code, GitHub issues, and docs")
```

Use the agent when:

- The investigation requires checking 3+ sources (docs, issues, source code, web)
- You need to synthesize findings across multiple sources into a coherent report
- The answer isn't available in a single document or file
- You want findings saved to a persistent file for future reference

Do NOT use the agent for:

- Simple lookups ("what flag does X?")
- Single-source answers (check docs directly)
- Codebase navigation (use Grep/Glob)

## The Research Phases

### Phase 1: External Research (Low Cost, Broad Coverage)

Start with publicly available information. This is cheap and fast.

1. **Search GitHub Issues** — Use `gh issue list --repo <repo> --search "<keywords>"` or WebSearch. Issues often contain detailed technical descriptions, including bug reports that reveal internals.
2. **Search Official Documentation** — Fetch the relevant docs pages. Note what IS documented and what's missing.
3. **Search Community Sources** — Blog posts, Stack Overflow, Discord threads. Use WebSearch with specific technical terms.
4. **Check Related Projects** — GitHub repos that interface with the tool often reverse-engineer or document internal behavior.

**When to stop:** If Phase 1 answers the question with High confidence, you're done. If any finding has Medium or lower confidence, or if sources contradict, proceed to Phase 2.

### Phase 2: Source Analysis (Higher Cost, Definitive Answers)

When external research leaves gaps, go to the source code.

**Escalate when:**

- External sources contradict each other
- Behavior observed doesn't match documentation
- You need the exact mechanism, not just "what it does"

**Steps:**

1. Locate source material (open-source repos, compiled bundles, package contents)
2. Search for entry points — start with user-visible behavior and trace backwards
3. Trace the call chain from the entry point
4. Verify with multiple evidence points — don't trust a single grep match

### Phase 3: Synthesis and Verification

1. Cross-reference Phase 1 and Phase 2 — do source findings explain external observations?
2. Correct earlier conclusions if source analysis contradicts Phase 1 findings
3. Document confidence levels explicitly
4. Write the final report with source references

## Confidence Level Framework

| Level           | Meaning                                               | Evidence Required                                           |
| :-------------- | :---------------------------------------------------- | :---------------------------------------------------------- |
| **Very High**   | Confirmed from source code with exact line references | Source code + verified call chain                           |
| **High**        | Confirmed from multiple independent external sources  | 3+ sources agree, or official docs + community confirmation |
| **Medium-High** | Strong evidence but some inference required           | 2 sources agree + logical reasoning                         |
| **Medium**      | Plausible with supporting evidence                    | 1 source + consistent with observed behavior                |
| **Low**         | Hypothesis based on limited evidence                  | Inference from related findings only                        |

## Report Structure Template

```markdown
# Research: <Topic>

**Researcher**: <Name>
**Date**: <Date>
**Question**: <The specific question being investigated>

## Executive Summary

<2-3 sentence answer>

## Methodology

<Which phases were used, what sources were consulted>

## Findings

### 1. <Finding>

<Detail with source references>
**Confidence**: <Level> — <evidence summary>

## Corrections to Previous Research

<If applicable — what changed and why>

## Open Questions

<What remains unanswered>

## Sources

- <Source with link or file:line reference>
```

## Tips

1. **Save everything to files** — Context compaction destroys in-memory state. Files survive.
2. **Use sub-agents for parallel fetches** — Launch background agents for simultaneous GitHub issue, docs, and URL fetching.
3. **Search with Grep, not Bash** — Built-in Grep handles large files better.
4. **Read 50-100 lines of context** — A single grep match is not enough.
5. **Track what you tried** — Document search terms that didn't work.
6. **Confidence levels are mandatory** — Every finding needs one.
7. **Correct previous research openly** — Being wrong in Phase 1 is expected.
