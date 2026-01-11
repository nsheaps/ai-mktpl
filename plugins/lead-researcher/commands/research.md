---
name: research
description: Deep research on a topic with parallel investigation, synthesis, and citations
argument-hint: "<question or topic>"
allowed-tools: Task, WebSearch, WebFetch, Grep, Glob, Read, Bash, TodoWrite
---

# Lead Researcher

Conduct comprehensive research on a complex question or topic, synthesizing findings from multiple sources with proper citations.

## Arguments

**Format:** `<question or topic>`

| Argument | Required | Description                               |
| -------- | -------- | ----------------------------------------- |
| question | Yes      | The research question or topic to explore |

**Examples:**

- `/research How does React Server Components work?`
- `/research Compare tRPC vs GraphQL for our use case`
- `/research What are best practices for API rate limiting?`
- `/research Why is our build so slow?`
- `/research Options for real-time data synchronization`

## Research Question

$ARGUMENTS

## Process

### Phase 1: Decomposition

First, decompose the research question into answerable sub-questions:

1. **Identify the core question** - What exactly needs to be answered?
2. **List sub-questions** - What must be understood first?
3. **Identify source types needed:**
   - Web (current docs, comparisons, best practices)
   - Codebase (architecture, patterns, current implementation)
   - Documentation (official docs, API references)
4. **Map dependencies** - Which questions depend on others?

Create a todo list to track research progress using TodoWrite.

### Phase 2: Parallel Investigation

Dispatch research agents for independent sub-questions:

**Use Task tool with appropriate subagent_type:**

| Research Type           | Agent Type        | When to Use                       |
| ----------------------- | ----------------- | --------------------------------- |
| Codebase exploration    | `Explore`         | Finding patterns, architecture    |
| Multi-step research     | `general-purpose` | Complex investigations            |
| Current web information | Direct WebSearch  | Comparisons, recent developments  |
| Specific documentation  | Direct WebFetch   | Known URLs, official docs         |

**Parallelization levels:**

- **8-10 parallel**: Pure information gathering
- **4-6 parallel**: Mixed research with analysis
- **2-3 parallel**: Complex analytical questions
- **Sequential**: Dependent questions (answer A needed for B)

**Agent prompt template:**

```
Research sub-question: [specific question]

Context: [why this matters to the main question]

Look for:
- [specific aspect 1]
- [specific aspect 2]

Return format:
- Key findings (bullet points)
- Source citations (URLs or file:line)
- Confidence level (high/medium/low)
- Any related findings worth noting
```

### Phase 3: Synthesis

After gathering findings:

1. **Organize by sub-question** - Group findings thematically
2. **Identify consensus** - What do multiple sources agree on?
3. **Note contradictions** - Where do sources differ? Why?
4. **Evaluate credibility:**
   - Official docs > reputable tech blogs > random posts
   - Recent (2024+) > older for fast-moving topics
   - Primary sources > secondary commentary
5. **Apply to context** - How do findings apply to user's situation?

### Phase 4: Deliver Results

Present findings in this structure:

```markdown
## Summary
[2-3 sentence answer to the core question]

## Key Findings

### [Theme/Sub-topic 1]
[Findings with inline citations]

### [Theme/Sub-topic 2]
[Findings with inline citations]

## Recommendation
[Specific, actionable guidance based on synthesis]

## Confidence Assessment
- Overall confidence: [High/Medium/Low]
- Areas of certainty: [what we know for sure]
- Areas of uncertainty: [what needs more investigation]

## Sources
- [Source Title](url) - [relevance note]
- `file_path:line` - [what was found]
```

## Citation Requirements

**CRITICAL: Every factual claim must be cited.**

Citation formats:
- Web: `[Title](url)` or `According to [source](url)...`
- Code: `file_path:line_number` or `The implementation in \`src/foo.ts:42\`...`
- Docs: `[Doc Name - Section](url)`

## Research Quality Checklist

Before delivering results, verify:

- [ ] Core question directly answered
- [ ] All sub-questions addressed
- [ ] Every claim has a citation
- [ ] Contradictions acknowledged and explained
- [ ] Recommendation is specific and actionable
- [ ] Confidence level stated honestly
- [ ] Sources section includes all references

## Handling Edge Cases

**Insufficient information:**
- State what was found and what's missing
- Suggest where to look next
- Provide partial answer with caveats

**Contradictory sources:**
- Present both perspectives
- Evaluate source credibility
- Offer reasoned assessment of which is more likely correct

**Question too broad:**
- Ask for clarification
- Suggest narrower research angles
- Offer to tackle one aspect first

**Out of scope:**
- Note tangential discoveries briefly
- Offer to research separately
- Stay focused on original question
