---
argument-hint: [what the new agent should do]
description: |-
  Use the meta-agent Agent/Sub-Agent to create a new agent for claude to use. Use /create-command if you want to create a slash command for the user instead.
---


Docs for reference:
- https://docs.anthropic.com/en/docs/claude-code/sub-agents


Using the ai-developer agent (see @~/src/gathertown-ai/.ai/agents/ai-developer.md ), create a new agent based on the input provided from the user ($ARGUMENTS). The new agent should be defined in a new file in @~/src/gathertown-ai/.ai/agents/ directory.

Note: Legacy agents are in @../agents/ but new consolidated agents are in @~/src/gathertown-ai/.ai/agents/

Ask clarifying questions about:
- The agent's specific role and capabilities
- What tools the agent should have access to
- The agent's expertise area and use cases
- Any special instructions or constraints

Agent file format:
- Create as `.md` file in `.ai/agents/` directory
- Include clear description of agent's purpose  
- Define the agent's capabilities and expertise
- Specify appropriate tone and approach
- Include usage examples if helpful

Example agent structure:
```markdown
# Agent Name

## Description
Brief description of what this agent does and when to use it.

## Capabilities
- List of specific capabilities
- Areas of expertise
- Types of tasks it handles

## Usage
When to use this agent and example scenarios.
```