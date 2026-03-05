# daily-report

Skill for generating comprehensive daily organization-wide reports covering all repositories in a GitHub org. Covers commits, pull requests, branches, issue changes, and force-push history tracing.

## Skills

### daily-report

Generates a full daily activity report across all repositories in a GitHub organization.

**Triggers on:**

- "generate a daily report"
- "summarize org activity"
- "what happened yesterday across the org"
- "daily activity report"
- "report on commits/PRs/issues across repos"

**What it does:**

- Scans all repositories in the org for activity in the time window
- Gathers commits across all branches per repository
- Detects force pushes and traces previous commit trees
- Collects PR activity (opened, merged, closed)
- Tracks branch creation and deletion
- Reports issue changes with state reasons
- Cross-references activity by author
- Outputs as GitHub-flavored Markdown

**Output**: Posted as a GitHub issue with label `daily-report`

## Scheduled Workflow

The `daily-report.yaml` workflow runs this skill:

- **Schedule**: Daily at 4:00 AM ET (9:00 AM UTC)
- **Manual dispatch**: With configurable time scope and subject scope inputs
- **Output**: GitHub issue titled `YYYY-MM-DD Daily Report` with label `daily-report`

## Requirements

- `gh` - GitHub CLI with org-level read access
- GitHub App token with repos, issues, and PRs permissions
