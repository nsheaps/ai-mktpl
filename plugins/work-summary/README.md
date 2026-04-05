# work-summary

Generate comprehensive work summaries across platforms for a person or agent over a time period.

## Skills

### work-summary

Produces a markdown report of all work done by an entity (person or agent) across available platforms, grouped by source.

**Triggers on:**

- "what did I do today"
- "show me my work from the last week"
- "summarize Eric's GitHub activity this sprint"
- "generate a standup report"
- "what did the team do yesterday"

**What it does:**

1. Resolves the entity's identity across available platforms (GitHub, Linear, Slack, Notion, etc.)
2. Queries each platform for activity in the specified time range
3. Produces a linked, grouped markdown report
4. Adds a summary section at the top
5. Optionally reformats for a specific format (e.g., standup: did/will do/blockers)

**Supported platforms** (when plugin/MCP is available):

| Platform | Data Collected                                        |
| -------- | ----------------------------------------------------- |
| GitHub   | PRs opened/merged/reviewed, commits, issues, comments |
| Linear   | Issues created/completed/updated, comments            |
| Slack    | Messages sent, threads participated in                |
| Notion   | Pages created/updated                                 |

## Installation

```bash
claude plugins add /path/to/work-summary
```

## Requirements

- At least one platform plugin or MCP server must be configured
- `gh` CLI for GitHub data
- Linear MCP for Linear data
- Slack MCP for Slack data
- Notion MCP for Notion data
