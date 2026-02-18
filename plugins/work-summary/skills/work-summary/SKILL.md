---
name: work-summary
description: Generate a comprehensive work summary across platforms (GitHub, Linear, Slack, Notion) for a person or agent over a time period
argument-hint: [entity] [time range] [format]
---

# Work Summary

Generate a comprehensive report of work performed by an entity across all available platforms.

**Arguments** ($ARGUMENTS): optional entity, time range, and output format.
- Entity defaults to the current authenticated user
- Time range defaults to "today" (since midnight local time)
- Format defaults to a grouped report; specify "standup" for did/will do/blockers format

Examples:
- `/work-summary` — your work today
- `/work-summary last week` — your work in the last 7 days
- `/work-summary @ericmorphis last 3 days` — another user's work
- `/work-summary today standup` — your work today in standup format

## Process

### Step 1: Parse Inputs

From $ARGUMENTS, determine:
1. **Entity**: a username, email, or "me" (default: current user)
2. **Time range**: natural language like "today", "last week", "last 3 days", "this sprint" (default: today)
3. **Output format**: "standup", "report", or other requested format (default: report)

If the entity is "me" or unspecified, use the `auth-user` skill (or `gh api user`) to resolve the current user's GitHub username as the primary identity.

### Step 2: Create the Report File

Create a report file at `.claude/tmp/work-summary-<entity>-<date>.md` with a placeholder structure:

```markdown
# Work Summary: <entity>
**Period:** <time range>
**Generated:** <timestamp>

## Summary
_Collecting data..._

## GitHub
_Querying..._

## Linear
_Querying..._

## Slack
_Querying..._

## Notion
_Querying..._
```

Update the file incrementally as data arrives from each platform — do not wait for all platforms before writing.

### Step 3: Resolve Entity Identity

For each available platform, resolve the entity's identity:

| Platform | How to Resolve |
|----------|---------------|
| GitHub | `gh api user` for self, or `gh api users/<username>` for others. Note the login and name. |
| Linear | Use Linear MCP `list_users` tool, match by name or email |
| Slack | Use Slack MCP `slack_search_users` tool, match by name or email |
| Notion | Use Notion MCP if available, match by name |

**IMPORTANT:** Only query platforms for which a plugin, MCP server, or CLI tool is actually available. Skip platforms that are not configured — do not error on missing platforms.

To check availability:
- **GitHub**: run `which gh` — if available, GitHub data can be collected
- **Linear**: check if Linear MCP tools are available via ToolSearch (search "linear")
- **Slack**: check if Slack MCP tools are available via ToolSearch (search "slack")
- **Notion**: check if Notion MCP tools are available via ToolSearch (search "notion")

### Step 4: Collect Data Per Platform

Query each available platform in parallel where possible. Update the report file after each platform completes.

#### GitHub (via `gh` CLI)

Collect the following for the entity in the time range:

```bash
# PRs authored (opened or merged)
gh pr list --author <username> --state all --search "created:>=<start-date>" --json number,title,state,url,createdAt,mergedAt,baseRefName

# PRs reviewed
gh api search/issues --method GET -f q="type:pr reviewed-by:<username> created:>=<start-date>" --jq '.items[] | {number: .number, title: .title, url: .html_url, repository: .repository_url}'

# Issues authored
gh api search/issues --method GET -f q="type:issue author:<username> created:>=<start-date>" --jq '.items[] | {number: .number, title: .title, url: .html_url, state: .state}'

# Commits (across repos the user is active in — use PR data to identify repos)
# For each repo found in PR data:
gh api repos/<owner>/<repo>/commits --method GET -f author=<username> -f since=<start-date-iso> --jq '.[] | {sha: .sha[:7], message: (.commit.message | split("\n")[0]), url: .html_url, date: .commit.author.date}'

# Comments on PRs/issues
gh api search/issues --method GET -f q="commenter:<username> updated:>=<start-date>" --jq '.items[] | {number: .number, title: .title, url: .html_url}'
```

Save raw output to `.claude/tmp/work-summary-gh-raw.json` for analysis, then update the report.

Format GitHub section as:

```markdown
## GitHub

### Pull Requests
- [PR #123: Add feature X](https://github.com/org/repo/pull/123) — **merged** into main
- [PR #456: Fix bug Y](https://github.com/org/repo/pull/456) — **open**, 3 comments

### Reviews
- Reviewed [PR #789: Refactor Z](https://github.com/org/repo/pull/789)

### Issues
- Opened [#101: Track performance regression](https://github.com/org/repo/issues/101)

### Commits
- `abc1234` Fix null pointer in auth handler (org/repo)
- `def5678` Add unit tests for parser (org/repo)
```

#### Linear (via MCP)

Use Linear MCP tools to collect:

1. `list_issues` filtered by assignee and date range — issues created, completed, or updated
2. `list_comments` for issues the entity commented on

Format Linear section as:

```markdown
## Linear

### Issues Completed
- [TEAM-123: Implement OAuth flow](https://linear.app/team/issue/TEAM-123) — completed

### Issues In Progress
- [TEAM-456: Add rate limiting](https://linear.app/team/issue/TEAM-456) — in progress, updated today

### Comments
- Commented on [TEAM-789: API redesign](https://linear.app/team/issue/TEAM-789)
```

#### Slack (via MCP)

Use Slack MCP tools to collect:

1. `slack_search_public_and_private` with `from:<username>` and date filter
2. Group by channel

Format Slack section as:

```markdown
## Slack

### #engineering (5 messages)
- Discussed deployment strategy for v2.0
- Shared PR link for auth refactor

### #incidents (2 messages)
- Reported API latency spike
- Updated incident timeline
```

**Note:** Summarize message content rather than quoting verbatim. Group by channel. Include thread participation.

#### Notion (via MCP)

Use Notion MCP tools to collect pages created or updated by the entity in the time range.

Format Notion section as:

```markdown
## Notion

### Pages Created
- [Q1 Planning Doc](https://notion.so/...)

### Pages Updated
- [Engineering Runbook](https://notion.so/...)
```

### Step 5: Write Summary

After all platform data is collected, write a summary section at the top of the report:

```markdown
## Summary

**<entity>** had an active day across <N> platforms:
- **GitHub**: Merged 2 PRs, reviewed 3, made 12 commits across 3 repos
- **Linear**: Completed 3 issues, updated 2 in progress
- **Slack**: Sent 15 messages across 4 channels
- **Notion**: Created 1 page, updated 2

Key highlights:
- Shipped the OAuth integration ([PR #123](url))
- Resolved the API latency incident
- Completed sprint planning for Q1
```

The summary should:
- Quantify activity per platform
- Highlight the most significant items (merged PRs, completed issues, incident responses)
- Be 5-10 lines maximum

### Step 6: Optional Reformatting

If the user requested a specific format, reformat the summary section accordingly.

#### Standup Format

```markdown
## Standup

### What I Did
- Merged PR for OAuth integration ([#123](url))
- Completed 3 Linear issues (TEAM-123, TEAM-456, TEAM-789)
- Reviewed 2 PRs from teammates

### What I'll Do Next
- _(User should fill in, or leave blank)_

### Blockers
- _(User should fill in, or leave blank)_
```

For standup format, only populate "What I Did" from collected data. Leave "What I'll Do Next" and "Blockers" as placeholders for the user to fill in.

### Step 7: Present to User

1. Save the final report to `.claude/tmp/work-summary-<entity>-<date>.md`
2. Remove any platform sections that had no data (don't show empty "Querying..." sections)
3. Present the summary section inline in conversation
4. Tell the user where the full report is saved

## Error Handling

- If a platform query fails, note the error in that section and continue with other platforms
- If no platforms are available, inform the user that at least one platform plugin/MCP must be configured
- If the entity cannot be found on a platform, skip that platform and note it in the summary
