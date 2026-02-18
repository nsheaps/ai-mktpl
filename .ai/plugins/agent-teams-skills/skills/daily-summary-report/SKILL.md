---
name: Daily Summary Report
description: >
  This skill should be used when the user asks to "generate a session report",
  "write a daily summary", "create a team report", "summarize today's work",
  "write up what we did", "generate end-of-session report", or when an agent
  team session is wrapping up and deliverables need to be documented. Guides
  the structured creation of comprehensive session reports covering agent
  roster, commits, issues, PRs, failures, and executive summary.
---

# Daily Summary Report

Generate a comprehensive session report documenting all work delivered by an agent team. The report serves as a permanent record of the session's output, a selling point for agent teams, and an honest accounting of what went well and what didn't.

**Origin**: Developed during the looney-tunes team's 2026-02-17 session. Process refined through 3 reviewer sign-offs and 14 revision items. See [session report](https://github.com/nsheaps/ai-mktpl/pull/164) for the context that drove this skill's creation.

## Report Structure

The report follows this section order. All sections are required unless marked optional.

```
1. Executive Summary          — TL;DR for the user (written last, placed first)
2. Table of Contents          — Auto-generated from section headers
3. Agent Roster               — Every agent that participated, with role/status/contributions
4. Tasks From Before Compaction — (Optional) Work carried forward from prior sessions
5. Work Delivered This Session — Commits by repo (key highlights + complete appendix)
6. GitHub Issues and PRs      — Every issue/PR created, with state and URLs
7. Issues Requiring Your Attention — User-action items grouped by type
8. Where We Fell Short        — Failures, shortcomings, platform limitations
9. Session Metrics            — Aggregate numbers
10. Next Steps                — Open risks, strategic direction, remaining work
Appendix A: Failure Log Reference
Appendix B: Session Timeline
Appendix C: Complete Commit Log
```

## Authoring Process

The report is a collaborative deliverable requiring three roles:

### Step 1: Engineer Drafts

The **Software Engineer** (or designated author) produces the initial draft by gathering data from all sources (see [Data Sources](#data-sources)).

**Draft checklist**:

- [ ] Agent roster with all fields populated (see [Agent Roster Format](#agent-roster-format))
- [ ] Complete commit log from all repos touched during the session
- [ ] All GitHub Issues listed with state (OPEN / CLOSED (completed) / CLOSED (not_planned))
- [ ] All PRs listed with state and merge status
- [ ] Failure descriptions copied from the failure log (not paraphrased)
- [ ] Timeline reconstructed from commit timestamps
- [ ] Executive summary left as placeholder for Coach

### Step 2: Coach Reviews

The **AI Agent Engineer / Coach** reviews for:

- **Accuracy**: Cross-reference commit hashes, failure descriptions, and issue states against source data
- **Completeness**: Identify missing failures, untracked action items, or uncredited work
- **Attribution**: Verify contributions are correctly attributed to the right agent
- **Executive summary**: Draft or co-write the executive summary

**Coach review output**: A review document listing corrections, additions, and the executive summary draft. Save to `.claude/tmp/session-report-review.md`.

### Step 3: Docs Writer Reviews

The **Technical Writer** reviews for:

- **Writing quality**: Section titles match content, consistent terminology
- **Structure**: All sections present, table of contents accurate
- **Links**: All URLs clickable, all references resolvable
- **Completeness**: No placeholder text remaining, metrics match actual counts

### Step 4: Reconciliation and Sign-Off

- All three reviewers' feedback is consolidated into a single change set
- Author incorporates all changes
- Each reviewer does a final pass and signs off
- Report is delivered to the team lead for user presentation

## Formatting Rules

### Links

Every reference MUST be a clickable markdown link:

```markdown
<!-- GOOD -->

[PR #164](https://github.com/nsheaps/ai-mktpl/pull/164)
[agent-team #59](https://github.com/nsheaps/agent-team/issues/59)
[`af6f0bf6`](https://github.com/nsheaps/ai-mktpl/commit/af6f0bf6)

<!-- BAD -->

PR #164
agent-team #59
af6f0bf6
```

### Issue States

Differentiate closed issue states:

| State                  | Meaning                       |
| ---------------------- | ----------------------------- |
| `OPEN`                 | Not yet resolved              |
| `CLOSED (completed)`   | Resolved as intended          |
| `CLOSED (not_planned)` | Won't fix / duplicate / stale |

Query state reason: `gh api repos/OWNER/REPO/issues/N --jq '.state_reason'`

### Commit Hashes

In the complete appendix, link every hash:

```markdown
[`af6f0bf6`](https://github.com/nsheaps/ai-mktpl/commit/af6f0bf6)
```

### Task References

Never use internal `Task #NNN` references in the report. Map them to GitHub Issues:

```markdown
<!-- BAD -->

Task #136 (statusline-iterm fix)

<!-- GOOD -->

[ai-mktpl #161](https://github.com/nsheaps/ai-mktpl/issues/161)
```

## Agent Roster Format

Each agent entry includes:

| Field         | Description                                |
| ------------- | ------------------------------------------ |
| Agent ID      | As shown in team config                    |
| subagent_type | general-purpose, Bash, team-lead, etc.     |
| Model         | claude-opus-4-6, opus, haiku, etc.         |
| Role          | One-line description                       |
| Launched      | When spawned (session number or timestamp) |
| Shut Down     | How/when terminated                        |
| Status        | Successful / Failed / Partial              |
| CWD           | Working directory                          |
| tmux Pane     | (If applicable) Pane ID                    |

Followed by: Notable Contributions (bulleted), Key Artifacts (file paths), Failures Attributed.

**Sub-agents** (Task tool agents that run to completion) should be listed separately with a note that they are not persistent team members.

## Issues Requiring Your Attention

This section lists OPEN issues that need the **user's** decision, action, or awareness. Group by type:

| Category                   | What qualifies                                                |
| -------------------------- | ------------------------------------------------------------- |
| **Decisions Needed**       | Strategic choices, license decisions, architectural direction |
| **Secrets / Manual Setup** | Credentials, repo settings, admin-only actions                |
| **Security**               | Vulnerabilities the user should know about                    |
| **Open Risks**             | Known issues that could cause problems                        |
| **Repo Cleanup**           | Destructive operations requiring user approval                |
| **Upstream / External**    | Issues in repos the team doesn't control                      |

**Rule**: If an action item isn't tracked as a GitHub Issue, create the issue first, then list it.

## Data Sources

| Source                                               | What to extract                                               |
| ---------------------------------------------------- | ------------------------------------------------------------- |
| `git log --all --oneline` (per repo)                 | Commits, authors, timestamps                                  |
| `gh issue list -s all --json number,title,state,url` | Issues with state                                             |
| `gh pr list -s all --json number,title,state,url`    | PRs with state                                                |
| `.claude/tmp/`                                       | Failure logs, review artifacts, research reports, audit files |
| `~/.claude/teams/{team-name}/config.json`            | Agent roster, IDs, pane assignments                           |
| TaskList / TaskGet                                   | Internal task state (map to GitHub Issues for report)         |
| Failure log (`.claude/tmp/*-failure-log.md`)         | Failure entries with root cause analysis                      |

### Gathering Commits

```bash
# For each repo touched during the session:
cd /path/to/repo
git log --oneline --since="YYYY-MM-DDT00:00:00" --until="YYYY-MM-DDT23:59:59" --format="%H|%aI|%s"
```

### Gathering Issues

```bash
gh issue list -R owner/repo -s all --json number,title,state,stateReason,url -L 500
```

## Common Pitfalls

These were discovered during the first report generation and should be avoided:

| Pitfall                                            | Fix                                                              |
| -------------------------------------------------- | ---------------------------------------------------------------- |
| Links not clickable (plain text references)        | Every issue, PR, and commit must be a markdown link              |
| "Key commits" shown but full log missing           | Always include complete commit log as appendix                   |
| Internal Task references in report                 | Map all `Task #NNN` to GitHub Issue URLs                         |
| No issue state differentiation                     | Query `state_reason` and show completed vs not_planned           |
| Executive summary has wrong counts                 | Verify totals by counting actual data, not estimating            |
| Valuable `.claude/tmp/` artifacts not preserved    | Move important artifacts to `docs/research/` before session ends |
| Commit count mismatch between summary and appendix | Count from the appendix, update summary to match                 |
| Section titles don't match content                 | "Work Delivered" = commits, "GitHub Issues" = issues             |

## Output Locations

1. **Primary**: `~/Documents/YYYY-MM-DD-claude-team-report.md`
2. **Backup**: Google Drive or other cloud storage copy
3. **Status file**: `.claude/tmp/report-update-status.md` — tracks what's been incorporated

## Executive Summary Guidelines

The executive summary is written last (after all data is gathered) but placed first in the report.

**Structure**:

1. **Opening line**: Team size, duration, scope (e.g., "A 10-agent team ran for ~5 hours across 5 repos")
2. **Headline deliverable**: The single most important thing shipped, with link
3. **By the numbers**: Commits, issues, PRs, releases, failures — all exact counts
4. **What worked well**: 3-4 bullets with specific evidence
5. **Where we fell short**: 3-4 bullets, honest, with failure numbers
6. **Assessment**: One paragraph — is agent teams viable? What's the honest take?

**Tone**: Factual, evidence-based, honest. Not a sales pitch. The numbers and quality speak for themselves. Acknowledge rough edges directly.
