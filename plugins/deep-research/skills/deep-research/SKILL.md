---
name: deep-research
description: |
  Use this skill when investigating complex questions that require multiple sources, angles, or synthesis. The deep-research plugin provides a 3-agent research team: lead-researcher (orchestrator), sub-researcher (workers), and critical-reviewer (validator).
  Trigger when:
  - Investigation requires 3+ sources (docs, issues, source code, web)
  - You need to synthesize findings across multiple sources into a coherent report
  - Previous research findings need source-level verification
  - You're investigating behavior differences between documented and observed behavior
  - Competitive analysis or technology evaluations
  Do NOT trigger for:
  - Simple lookups ("what flag does X?")
  - Single-source answers
  - Basic codebase navigation (use Grep/Glob directly)
---

# Deep Research -- 3-Agent Research System

A multi-agent research system for complex, evidence-based investigations.

## Architecture

The deep-research plugin uses three specialized agents:

```
User Request
    |
    v
lead-researcher (orchestrator)
    |-- Plans 5-10 search angles
    |-- Dispatches sub-researchers (one per angle)
    |       |-- sub-researcher 1: Angle A (web + docs)
    |       |-- sub-researcher 2: Angle B (source code)
    |       |-- sub-researcher 3: Angle C (community)
    |       |-- ... (up to 10 angles)
    |
    |-- Collects findings from all sub-researchers
    |-- Dispatches critical-reviewer to validate
    |-- Addresses gaps from review
    |-- Synthesizes final report
    |
    v
Report saved to .claude/tmp/research-<topic>.md
```

### Agents

| Agent | Role | Tools | Restrictions |
|-------|------|-------|-------------|
| **lead-researcher** | Orchestrator -- plans angles, dispatches workers, synthesizes report | Read, Write, Grep, Glob, Agent | No web search (delegates to sub-researchers) |
| **sub-researcher** | Worker -- investigates one specific angle, writes findings to file | Read, Write, Grep, Glob, WebSearch, WebFetch | No Edit (shouldn't modify existing files) |
| **critical-reviewer** | Validator -- challenges assumptions, identifies gaps, suggests follow-up | Read, Grep, Glob, WebSearch, WebFetch | No Edit, no Write (read-only reviewer) |

## How to Invoke

For complex, multi-source investigations, spawn the lead-researcher agent:

```
Agent(lead-researcher, "Investigate how Claude Code spawns teammates -- check source code, official docs, GitHub issues, and community implementations. Save report to .claude/tmp/research-teammate-spawning.md")
```

The lead-researcher will autonomously:
1. Plan research angles
2. Dispatch sub-researchers for each angle
3. Collect and cross-reference findings
4. Run critical review
5. Produce final report with confidence levels and citations

## When to Use Deep Research vs Simple Lookups

| Situation | Use |
|-----------|-----|
| "What flag enables X?" | Direct answer -- no agent needed |
| "How does X work internally?" | lead-researcher -- multi-source investigation |
| "Compare X vs Y vs Z for our use case" | lead-researcher -- parallel sub-researchers per option |
| "Find the file that does X" | Grep/Glob -- no agent needed |
| "Why does X behave differently than documented?" | lead-researcher -- needs source + docs + issues |
| "What's the best practice for X?" | Context7 or WebSearch -- single source usually sufficient |

## Output Format

Reports are saved to `.claude/tmp/research-<topic>.md` with:

- **Executive Summary**: 2-3 sentence answer
- **Methodology**: Angles pursued, sources consulted
- **Findings**: Each finding with confidence level and citations
- **Critical Review Notes**: What was challenged, how addressed
- **Open Questions**: What remains unanswered
- **Sources**: Complete list of all references

## Confidence Level Framework

| Level | Meaning | Evidence Required |
|:------|:--------|:------------------|
| **Very High** | Confirmed from source code or official specs | Primary source + verified |
| **High** | Multiple independent sources agree | 3+ sources or official docs + community |
| **Medium-High** | Strong evidence with some inference | 2 sources + logical reasoning |
| **Medium** | Plausible with supporting evidence | 1 source + consistent behavior |
| **Low** | Hypothesis based on limited evidence | Inference only |

## Tips

1. **Save everything to files** -- Context compaction destroys in-memory state. Files survive.
2. **The lead-researcher dispatches sub-researchers** -- You don't need to manage them manually.
3. **Critical review catches gaps** -- The critical-reviewer challenges weak evidence before the report is finalized.
4. **Confidence levels are mandatory** -- Every finding needs one.
5. **Correct previous research openly** -- Being wrong in early phases is expected and documented.

## References

- [Claude Code Sub-Agents](https://code.claude.com/docs/en/sub-agents)
- [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams)
- [Community lead-researcher patterns](https://github.com/rewolfiluac/MLFlowDockerSetup/blob/main/.claude/agents/lead-researcher.md)
