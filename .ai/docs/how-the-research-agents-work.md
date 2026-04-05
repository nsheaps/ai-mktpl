# Claude Code Research Agent Files

This directory contains Claude Code agent files that replicate the behavior of Anthropic's "Lead Researcher" multi-agent research system.

## Files

- `research-lead.md` - The lead research agent (orchestrator)
- `research-subagent.md` - The research subagent (worker)

## Usage

In Claude Code, you can invoke these agents by:

- "Use the research-lead agent to research [topic]"
- The lead agent will automatically spawn subagents for complex queries

## Architecture Overview

This replicates Anthropic's multi-agent research system architecture:

```
┌─────────────────────────────────────────────────────────┐
│                    User Query                           │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│              Lead Research Agent (Opus)                 │
│  - Analyzes query complexity                            │
│  - Creates research plan                                │
│  - Spawns subagents in parallel                         │
│  - Synthesizes final results                            │
└───────┬─────────────┬─────────────┬─────────────────────┘
        │             │             │
        ▼             ▼             ▼
┌───────────┐   ┌───────────┐   ┌───────────┐
│ Subagent  │   │ Subagent  │   │ Subagent  │
│ (Sonnet)  │   │ (Sonnet)  │   │ (Sonnet)  │
│           │   │           │   │           │
│ OODA Loop │   │ OODA Loop │   │ OODA Loop │
└───────────┘   └───────────┘   └───────────┘
        │             │             │
        └─────────────┼─────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│              Synthesized Research Report                │
└─────────────────────────────────────────────────────────┘
```

## Key Features Replicated

### From the Lead Agent

- **Query complexity assessment** - Simple/Medium/Complex classification
- **Parallel subagent spawning** - 3-5 subagents simultaneously
- **Research plan persistence** - Memory management for long sessions
- **Synthesis guidelines** - Theme-based organization with citations

### From the Subagents

- **OODA Loop methodology** - Observe, Orient, Decide, Act
- **Adaptive effort scaling** - Tool calls scaled to task complexity
- **Start broad, narrow down** - Mirrors expert human research
- **Parallel tool calling** - Multiple searches simultaneously
- **Epistemic honesty** - Source quality verification and uncertainty flagging

## Source Documentation

These agent files were created based on official Anthropic documentation:

### Primary Sources

1. **Anthropic Engineering Blog: "How we built our multi-agent research system"**
   - URL: https://www.anthropic.com/engineering/multi-agent-research-system
   - Published: June 2025
   - Contains: Architecture overview, prompt engineering principles, evaluation methods

2. **Anthropic Cookbook - Official Prompts**
   - URL: https://github.com/anthropics/anthropic-cookbook/tree/main/patterns/agents/prompts
   - Files: `research_lead_agent.md`, `research_subagent.md`
   - Status: Official open-source examples from Anthropic

### Secondary Sources (Analysis)

3. **Simon Willison's Analysis**
   - URL: https://simonwillison.net/2025/Jun/14/multi-agent-research-system/
   - Contains: Excerpts from official prompts including `<use_parallel_tool_calls>` and OODA loop sections

4. **ByteByteGo Analysis**
   - URL: https://blog.bytebytego.com/p/how-anthropic-built-a-multi-agent
   - Contains: Architecture breakdown and prompt engineering insights

## Key Metrics from Anthropic

According to Anthropic's internal evaluations:

- Multi-agent (Opus lead + Sonnet subagents) outperforms single-agent Opus by **90.2%**
- Multi-agent systems use approximately **15x more tokens** than chat interactions
- Parallel tool calling cut research time by up to **90%** for complex queries
- Token usage explains **80%** of performance variance (more tokens = better results)

## Limitations

These files are approximations based on public documentation. The actual production system includes:

- Proprietary tool definitions
- Custom MCP server integrations
- CitationAgent for final attribution processing
- Additional safety and quality guardrails
- Production-grade error handling and recovery

## Customization

You can customize these agents by:

1. Adjusting the `model` field (opus/sonnet/haiku)
2. Modifying `tools` for your available MCP servers
3. Adding domain-specific instructions to the prompts
4. Adjusting complexity thresholds for your use case

## License

These agent files are provided for educational and personal use. The underlying patterns are derived from Anthropic's public documentation and open-source cookbook.
