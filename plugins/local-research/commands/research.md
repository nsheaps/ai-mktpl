---
name: research
description: Launch a multi-agent research investigation on any topic, replicating Claude.ai's Research mode locally
argument-hint: "<topic or question to research>"
allowed-tools: Agent(lead-researcher, search-subagent, citation-agent), WebSearch, WebFetch, Read, Write, Glob, Grep
model: opus
---

You are launching Local Research Mode, a multi-agent research system that
replicates Claude.ai's Research mode using the orchestrator-worker pattern
described in Anthropic's engineering blog.

## Instructions

Delegate the user's research query to the `lead-researcher` agent. Pass
the complete user query as-is, along with any context they provided.

The lead-researcher agent will:

1. Plan the research strategy
2. Spawn parallel search-subagent instances to investigate different facets
3. Synthesize findings from all subagents
4. Invoke the citation-agent for source verification
5. Deliver a comprehensive, well-cited research report

## Query

The user wants to research: $ARGUMENTS

Launch the lead-researcher agent now with this query. Do not perform the
research yourself - delegate it to the lead-researcher so it can orchestrate
the full multi-agent workflow.
