# deep-researcher

Deep research agent for complex, multi-source investigations.

## What it does

Provides a `deep-researcher` agent definition that performs thorough, evidence-based research across multiple sources. Designed for investigations that require synthesis — not simple lookups.

## Use cases

- **Deep technical investigations** — How does system X work internally? What are the edge cases?
- **Market and competitive research** — How do competitors solve this problem?
- **Technology evaluations** — Evidence-based comparisons of tools, libraries, or approaches
- **Multi-source synthesis** — Combining findings from code, docs, issues, and web resources

## Installation

Install via the `ai-mktpl` marketplace:

```bash
claude plugin install deep-researcher
```

## Usage

The agent is automatically available after installation. Invoke it when you need complex research:

```
Use the deep-researcher agent to investigate how MCP servers handle authentication across different frameworks.
```

Reports are saved to files (typically `.claude/tmp/`) with full source citations and confidence levels.

## What it is NOT for

- Simple lookups or "how do I do X" questions
- Single-source answers
- Codebase exploration (use Grep/Glob or the Explore agent)

## Source

Agent definition originally from [nsheaps/agent-team](https://github.com/nsheaps/agent-team).
