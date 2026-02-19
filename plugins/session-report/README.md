# session-report

Skill for generating structured session reports — fact-finding across git history, GitHub issues and PRs, tasks, and contributions to produce a comprehensive work summary.

Works for **solo agents and agent teams alike**.

## Skills

### session-report

Guides the full lifecycle of a session report: creation at session start, incremental updates as work progresses, and finalized review at session end.

**Triggers on:**

- "generate a session report"
- "write a daily summary"
- "summarize today's work"
- "write up what we did"
- "generate end-of-session report"
- "update the report"
- "add my work to the report"

**What it does:**

- Defines a structured report format covering commits, issues, PRs, failures, metrics, and next steps
- Guides incremental updates throughout a session (not just end-of-day generation)
- Provides fact-finding data sources: `git log`, `gh issue list`, `gh pr list`, task logs
- Covers finalization: validation, review for accuracy, review for quality, delivery

**Output location**: `~/Documents/YYYY-MM-DD-session-report.md`

## Installation

```bash
claude plugin add /path/to/session-report
```

## Requirements

- `git` - Git CLI
- `gh` - GitHub CLI (for issues, PRs, and state reasons)
