---
name: Local Research Mode
description: >-
  Use this skill when the user asks to "research", "investigate", "deep dive",
  "find out about", "look into", "comprehensive analysis", or any request that
  benefits from multi-source web research with parallel search agents and
  citation verification. This is the local equivalent of Claude.ai's Research
  mode, using the same multi-agent orchestrator-worker architecture described
  in Anthropic's engineering blog.
---

# Local Research Mode

This plugin replicates Claude.ai's Research mode locally using Claude Code's
native subagent system. It implements the same multi-agent architecture
described in Anthropic's engineering blog post
["How we built our multi-agent research system"](https://www.anthropic.com/engineering/multi-agent-research-system).

## Architecture

The system uses three specialized agents in an orchestrator-worker pattern:

### LeadResearcher (Opus)

The orchestrating agent that:

- Analyzes the user's query and assesses complexity
- Develops a research strategy and decomposes it into parallel subtasks
- Spawns search subagents to investigate each subtask simultaneously
- Synthesizes findings from all subagents into a coherent report
- Decides whether additional research rounds are needed
- Invokes the citation agent for source verification

### SearchSubagent (Sonnet)

Specialized research workers (typically 3-5 spawned in parallel) that:

- Execute focused web searches with varied query formulations
- Fetch and read full source content (not just search snippets)
- Evaluate source quality and authority
- Return structured findings with URLs for every claim

### CitationAgent (Sonnet)

A post-processing agent that:

- Audits all factual claims for proper source attribution
- Spot-checks cited URLs to verify they support the claims
- Flags dead links, misattributed claims, and unsourced assertions
- Formats a verified source list

## How It Works

1. **User submits a research query** (via `/research` command or natural language)
2. **LeadResearcher plans** the research strategy using extended thinking
3. **3-5 SearchSubagents spawn in parallel**, each investigating a different facet
4. **Subagents return findings** with structured data and source URLs
5. **LeadResearcher synthesizes** all findings, checking for gaps or contradictions
6. **Additional subagents spawn** if gaps are identified (iterative refinement)
7. **CitationAgent verifies** source attribution and formats citations
8. **Final report delivered** with key findings, detailed analysis, and verified sources

## Usage

### Via Command

```
/research What are the current approaches to quantum error correction?
```

### Via Natural Language

Simply ask Claude to research something:

```
Research the current state of RISC-V adoption in data centers
Investigate recent advances in solid-state battery technology
Do a deep dive into the history and current state of WebAssembly
```

### Effort Levels

The LeadResearcher automatically scales effort based on query complexity:

- **Simple queries**: 1-2 subagents, 3-10 tool calls each
- **Comparative queries**: 2-4 subagents, 10-15 calls each
- **Complex/multi-faceted**: 5-10 subagents, 15+ calls each

## Design Principles

These principles are drawn directly from Anthropic's published research:

1. **Parallel execution**: Subagents work simultaneously, not sequentially.
   This cuts research time by up to 90% for complex queries.

2. **Start broad, then narrow**: Initial searches cast a wide net.
   Follow-up searches target specific gaps discovered in initial results.

3. **Source quality over quantity**: Prefer academic papers, official docs,
   primary sources, and established publications over SEO content farms.

4. **Heuristics over rigid rules**: Agents encode human research strategies
   (decomposing questions, evaluating sources, adjusting approaches) rather
   than following fixed scripts.

5. **Memory persistence**: The LeadResearcher saves its plan to persist
   context if the research exceeds token limits.

6. **Token awareness**: Multi-agent research uses ~15x more tokens than
   standard chat. The system scales effort to match query complexity.

## Token Usage

Research mode is significantly more token-intensive than standard conversation:

- Standard chat: 1x tokens
- Single-agent research: ~4x tokens
- Multi-agent research: ~15x tokens

The LeadResearcher attempts to calibrate effort to avoid wasting tokens on
simple queries while being thorough on complex ones.

## References

- [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) - Anthropic Engineering
- [Research agent prompts (anthropic-cookbook)](https://github.com/anthropics/anthropic-cookbook/tree/main/patterns/agents/prompts) - Actual system prompts published by Anthropic
- [Simon Willison's analysis](https://simonwillison.net/2025/Jun/14/multi-agent-research-system/)
- [Using Research on Claude](https://support.claude.com/en/articles/11088861-using-research-on-claude) - Claude Help Center
