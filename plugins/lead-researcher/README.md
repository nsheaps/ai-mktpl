# Lead Researcher Plugin

A comprehensive research coordination plugin that decomposes complex questions into parallel investigation threads, synthesizes findings from multiple sources, and delivers well-cited answers.

## Features

- **Question Decomposition**: Automatically breaks complex questions into answerable sub-questions
- **Parallel Research**: Dispatches multiple research agents simultaneously for faster results
- **Multi-Source Synthesis**: Combines findings from web, codebase, and documentation
- **Citation Tracking**: Every claim is backed by a source (URL or file:line reference)
- **Confidence Assessment**: Honest evaluation of finding reliability

## Installation

```bash
# From the marketplace
/plugin install lead-researcher@nsheaps-claude-plugins

# Or manually symlink
ln -s /path/to/lead-researcher ~/.claude/plugins/lead-researcher
```

## Usage

### Slash Command

```bash
/research <question or topic>
```

**Examples:**

```bash
/research How does React Server Components work?
/research Compare tRPC vs GraphQL for our API
/research What are best practices for API rate limiting?
/research Why is our build taking so long?
/research Options for real-time synchronization
```

### Auto-Activation (Skill)

The skill automatically activates when Claude detects research-worthy questions:

- "How does X work?"
- "What are the best practices for..."
- "Compare X vs Y"
- "Investigate why..."
- "What are my options for..."

**Trigger phrases:** research, investigate, deep dive, comprehensive analysis, compare, explain how, find out why, look into, thorough answer

## How It Works

### 1. Decomposition

The researcher first breaks your question into sub-questions:

```
User: "Should we use tRPC or GraphQL?"

Sub-questions:
1. What's our current tech stack? (codebase)
2. What are tRPC's pros/cons? (web)
3. What are GraphQL's pros/cons? (web)
4. What are our team's preferences? (CLAUDE.md)
5. What are our API consumer needs? (context)
```

### 2. Parallel Investigation

Independent sub-questions are researched simultaneously:

- **Explore agents**: Codebase analysis, architecture patterns
- **Web searches**: Current comparisons, documentation
- **Direct reads**: Known files, configuration

### 3. Synthesis

Findings are collated, evaluated, and synthesized:

- Consensus points identified
- Contradictions noted and explained
- Credibility assessed (official docs > blogs > posts)
- Context applied to your specific situation

### 4. Structured Response

Results delivered with:

- Executive summary
- Key findings by theme
- Specific recommendation
- Confidence assessment
- Full source citations

## Output Format

```markdown
## Summary
[2-3 sentence answer]

## Key Findings

### [Topic 1]
Finding with [citation](url)...

### [Topic 2]
Analysis from `src/file.ts:42`...

## Recommendation
[Actionable guidance]

## Confidence Assessment
- Overall: Medium
- Certain: [aspects]
- Uncertain: [aspects]

## Sources
- [Doc Title](url) - relevance
- `path/file.ts:line` - what was found
```

## Configuration

### Allowed Tools

The plugin uses these tools:
- `Task` - Spawning research agents
- `WebSearch` - Current web information
- `WebFetch` - Specific documentation
- `Grep`, `Glob`, `Read` - Codebase exploration
- `Bash` - Git history, file operations
- `TodoWrite` - Progress tracking

### Parallelization Levels

| Complexity | Parallel Agents | Use Case                    |
| ---------- | --------------- | --------------------------- |
| Simple     | 8-10            | Pure information gathering  |
| Medium     | 4-6             | Mixed research + analysis   |
| Complex    | 2-3             | Analytical questions        |
| Dependent  | Sequential      | Answer A needed for B       |

## Best Practices

1. **Be specific**: "How does X work in our codebase?" > "How does X work?"
2. **Provide context**: Mention constraints, preferences, or requirements
3. **Scope appropriately**: Break very broad questions into focused research sessions
4. **Follow up**: Ask clarifying questions if findings need deeper exploration

## Plugin Contents

```
lead-researcher/
├── .claude-plugin/
│   └── plugin.json        # Plugin metadata
├── commands/
│   └── research.md        # /research slash command
├── skills/
│   └── lead-researcher/
│       └── SKILL.md       # Auto-activation skill
└── README.md              # This file
```

## Version History

- **0.1.0**: Initial release with research command and skill
