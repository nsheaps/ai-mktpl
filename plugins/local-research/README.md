# Local Research Mode

Replicates Claude.ai's Research mode locally using Claude Code's native subagent system. Implements the same multi-agent orchestrator-worker architecture described in [Anthropic's engineering blog](https://www.anthropic.com/engineering/multi-agent-research-system).

## Architecture

```
User Query
    │
    ▼
┌─────────────────────┐
│  LeadResearcher     │  (Opus) Plans, coordinates, synthesizes
│  (orchestrator)     │
└─────────┬───────────┘
          │ spawns 3-5 in parallel
    ┌─────┼─────┐
    ▼     ▼     ▼
┌──────┐┌──────┐┌──────┐
│Search││Search││Search│  (Sonnet) Focused web search + source reading
│Sub 1 ││Sub 2 ││Sub N │
└──┬───┘└──┬───┘└──┬───┘
   └───────┼───────┘
           ▼
┌─────────────────────┐
│  CitationAgent      │  (Sonnet) Verifies sources, formats citations
└─────────────────────┘
           │
           ▼
    Final Report
```

## Components

| Component         | Type    | Model  | Purpose                                                        |
| ----------------- | ------- | ------ | -------------------------------------------------------------- |
| `lead-researcher` | Agent   | Opus   | Orchestrates research, spawns subagents, synthesizes findings  |
| `search-subagent` | Agent   | Sonnet | Executes focused web searches, reads sources, returns findings |
| `citation-agent`  | Agent   | Sonnet | Verifies source attribution, formats citations                 |
| `research-mode`   | Skill   | -      | Documents the architecture and usage patterns                  |
| `/research`       | Command | Opus   | Quick-launch command for research queries                      |

## Usage

### Via Slash Command

```
/research What are the current approaches to quantum error correction?
```

### Via Natural Language

```
Research the current state of RISC-V adoption in data centers
```

The `lead-researcher` agent triggers automatically when it detects research-oriented queries.

## How It Differs from Claude.ai

| Aspect                | Claude.ai Research            | This Plugin                              |
| --------------------- | ----------------------------- | ---------------------------------------- |
| Search backend        | Brave Search (server-side)    | WebSearch tool (Claude Code built-in)    |
| Source reading        | Internal fetch infrastructure | WebFetch tool                            |
| Orchestrator model    | Opus                          | Opus                                     |
| Worker model          | Sonnet                        | Sonnet                                   |
| Max subagents         | Configurable (server-side)    | Limited by Claude Code's subagent system |
| Google Workspace      | Supported                     | Not supported                            |
| Citation verification | CitationAgent                 | CitationAgent                            |

## Design Decisions

Based on research into Anthropic's architecture and existing open-source attempts:

1. **Three-agent pattern** matches Anthropic's published architecture: LeadResearcher, SearchSubagents, CitationAgent
2. **Opus for orchestration, Sonnet for workers** matches their model allocation strategy
3. **Parallel subagent spawning** is critical - sequential execution loses the 90% speedup
4. **Source quality heuristics** embedded in prompts to avoid SEO content farms
5. **Iterative refinement** - LeadResearcher can spawn additional subagents if gaps found
6. **Min 8-10 sources** for standard queries matches the depth Claude.ai targets

## References

- [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) - Anthropic Engineering
- [Simon Willison's analysis](https://simonwillison.net/2025/Jun/14/multi-agent-research-system/)
- [Using Research on Claude](https://support.claude.com/en/articles/11088861-using-research-on-claude) - Claude Help Center
