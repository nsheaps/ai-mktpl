# deep-research

Multi-agent deep research system for complex, evidence-based investigations.

## Overview

The deep-research plugin provides a 3-agent research team that handles complex investigations requiring multiple sources, synthesis, and critical validation. It replaces simple single-agent research with an orchestrated workflow.

## Architecture

```
User Request
    |
    v
lead-researcher (orchestrator)
    |-- Plans 5-10 search angles
    |-- Dispatches sub-researchers (one per angle)
    |-- Collects findings
    |-- Dispatches critical-reviewer
    |-- Synthesizes final report
    |
    v
Report saved to .claude/tmp/research-<topic>.md
```

### Agents

| Agent | Role | Description |
|-------|------|-------------|
| **lead-researcher** | Orchestrator | Plans research angles, dispatches sub-researchers, synthesizes report |
| **sub-researcher** | Worker | Investigates one specific angle, searches web/docs/code, writes findings to file |
| **critical-reviewer** | Validator | Reviews findings, challenges assumptions, identifies gaps (read-only) |

## Usage

Invoke the lead-researcher agent for any complex, multi-source investigation:

```
Agent(lead-researcher, "Investigate <topic>. Save report to .claude/tmp/research-<topic>.md")
```

The lead-researcher autonomously handles the full workflow: planning, dispatching sub-researchers, critical review, and synthesis.

## When to Use

- Investigations requiring 3+ sources
- Technology evaluations and comparisons
- Understanding undocumented internal behavior
- Competitive analysis
- Any question where synthesis across multiple sources adds value

## When NOT to Use

- Simple lookups ("what flag does X?")
- Single-source answers
- Basic codebase navigation (use Grep/Glob directly)

## Output

Reports include executive summary, methodology, findings with confidence levels, critical review notes, open questions, and full source citations.

## Installation

Install via the ai-mktpl marketplace:

```
claude plugin install deep-research --marketplace nsheaps/ai-mktpl
```
