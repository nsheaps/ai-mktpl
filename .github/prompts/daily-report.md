You are generating a daily activity report. Use the daily-report skill from the daily-report plugin.

## Parameters

- **Report Date**: ${REPORT_DATE}
- **Time Scope**: ${TIME_SCOPE}
- **Subject Scope**: ${SUBJECT_SCOPE}

## Instructions

1. Use `gh` CLI to gather data from all repositories in the scope. The GH_TOKEN is already configured.
2. Follow the daily-report skill instructions exactly for data gathering:
   - List active repos in the org/scope
   - Gather commits across all branches per repo
   - Detect force pushes and trace previous commit trees (try audit log first, fall back to events API)
   - Gather PR activity (opened, merged, closed, updated)
   - Track branch creation and deletion
   - Report issue changes with state reasons (completed vs not_planned)
3. Generate the full report in GitHub-flavored Markdown following the skill's report format
4. Post the report as a GitHub issue using `mcp__github__create_issue` with:
   - owner: "nsheaps"
   - repo: "ai-mktpl"
   - title: "${REPORT_DATE} Daily Report"
   - labels: ["daily-report"]
   - body: the full report markdown

## Important

- All times should be displayed in US Eastern Time
- All SHAs, issue numbers, and PR numbers must be clickable markdown links
- Sort repos alphabetically, commits chronologically
- Skip repos with zero activity
- If any API calls fail or are rate-limited, note it in the Methodology section
- Do NOT include repos that had no activity in the time window
