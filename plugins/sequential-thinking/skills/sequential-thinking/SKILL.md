---
name: sequential-thinking
description: >
  Use this skill when you need to break down complex problems, plan multi-step
  implementations, analyze tricky bugs, make architectural decisions, reason
  through ambiguous requirements, or any task that benefits from structured
  step-by-step thinking. Also use when you need to revise earlier assumptions,
  explore alternative approaches, or verify a hypothesis before committing to
  an implementation.
---

# Sequential Thinking - Structured Problem Solving

The sequential-thinking MCP server provides a tool for dynamic, reflective
problem-solving through structured thought steps. Unlike simple chain-of-thought,
it supports revision, branching, and adaptive depth.

## When to Use

- **Complex multi-step problems**: Break down into manageable thought steps
- **Architectural decisions**: Evaluate trade-offs with room for revision
- **Bug analysis**: Systematically narrow down root causes
- **Ambiguous requirements**: Explore interpretations before committing
- **Planning with uncertainty**: Adjust approach as understanding deepens
- **Hypothesis verification**: Generate and test theories step by step

## The Tool

### `mcp__sequential-thinking__sequentialthinking`

Each call represents one thought step. Key parameters:

| Parameter           | Type   | Description                           |
| ------------------- | ------ | ------------------------------------- |
| `thought`           | string | Your current thinking step            |
| `thoughtNumber`     | int    | Current step number (1-based)         |
| `totalThoughts`     | int    | Estimated total steps (adjustable)    |
| `nextThoughtNeeded` | bool   | `true` if more thinking needed        |
| `isRevision`        | bool   | Whether this revises a prior thought  |
| `revisesThought`    | int    | Which thought number is being revised |
| `branchFromThought` | int    | Which thought to branch from          |
| `branchId`          | string | Identifier for the branch             |
| `needsMoreThoughts` | bool   | Signal that you need more steps       |

## Workflow Patterns

### Linear Analysis

For straightforward problems where each step builds on the last:

```
Thought 1: Understand the problem space
Thought 2: Identify key constraints
Thought 3: Propose solution approach
Thought 4: Verify approach against constraints
Thought 5: Final answer (nextThoughtNeeded: false)
```

### Revision-Based

When early assumptions prove wrong:

```
Thought 1: Initial hypothesis
Thought 2: Gather evidence
Thought 3: Evidence contradicts hypothesis
Thought 4: (isRevision=true, revisesThought=1) Revised hypothesis
Thought 5: Verify revised hypothesis
```

### Branching Exploration

When multiple approaches deserve evaluation:

```
Thought 1: Problem statement
Thought 2: Approach A analysis
Thought 3: (branchFromThought=1, branchId="B") Approach B analysis
Thought 4: Compare branches
Thought 5: Select best approach
```

### Adaptive Depth

Start with a small estimate, expand as needed:

```
Thought 1/3: Initial analysis
Thought 2/3: Deeper than expected...
Thought 3/5: (needsMoreThoughts=true, totalThoughts=5) Need more analysis
Thought 4/5: Additional investigation
Thought 5/5: Conclusion
```

## Best Practices

### Do

- **Start with a reasonable estimate** of total thoughts (3-5 for simple, 7-10 for complex)
- **Adjust totalThoughts** dynamically as you learn more
- **Use revisions** freely when new information changes earlier conclusions
- **Branch** when genuinely torn between approaches
- **Express uncertainty** in thought steps rather than forcing premature conclusions
- **Filter irrelevant information** in each step
- **Verify your hypothesis** before setting `nextThoughtNeeded: false`

### Don't

- **Don't pad thoughts** - if you reach a conclusion early, stop
- **Don't force linearity** - branch or revise when needed
- **Don't use for simple tasks** - direct action is better than overthinking
- **Don't set nextThoughtNeeded=false** until you're truly satisfied
- **Don't ignore contradictory evidence** - use revisions instead

## Example Use Cases

### Debugging a Race Condition

```
Thought 1: Identify the symptoms (intermittent failure, timing-dependent)
Thought 2: Map the concurrent operations involved
Thought 3: Identify shared state access points
Thought 4: Hypothesize: shared counter accessed without lock
Thought 5: Verify: trace code paths to confirm hypothesis
Thought 6: Propose fix with verification strategy
```

### Choosing a Database Schema

```
Thought 1: Document access patterns and query requirements
Thought 2: Branch A - normalized relational schema
Thought 3: Branch B - denormalized for read performance
Thought 4: Compare against access patterns
Thought 5: Revise - hybrid approach combining strengths
Thought 6: Validate against edge cases
```

### Planning a Refactor

```
Thought 1: Understand current architecture and pain points
Thought 2: Identify dependencies and blast radius
Thought 3: Propose incremental migration strategy
Thought 4: Identify risks and rollback plan
Thought 5: Break into atomic, shippable steps
```

## Integration Notes

This plugin:

- Declares the MCP server via `.mcp.json` (auto-registered on install)
- Auto-adds `mcp__sequential-thinking__*` to permissions.allow on session start
- No manual configuration needed after plugin installation
