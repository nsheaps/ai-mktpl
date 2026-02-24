---
name: session-report
description: >
  Use this skill when asked to "generate a session report", "write a daily
  summary", "summarize today's work", "write up what we did",
  "generate end-of-session report", "update the report", or "add my work
  to the report". Works for solo agents and agent teams alike. Guides the
  full lifecycle of session reports: creation, incremental updates
  throughout the day, and final review.
---

# Session Report

A living document maintained throughout a work session. The report is created at session start, updated incrementally as work progresses, and finalized through a review process at session end.

This is NOT a one-shot end-of-day generation. Contributions should be added to the report as work is completed — not all at the end.

**Origin**: Developed during the looney-tunes agent team's 2026-02-17 session. Process refined through 3 reviewer sign-offs and 14 revision items. See [ai-mktpl#175](https://github.com/nsheaps/ai-mktpl/pull/175) for the PR that created this skill.

## Report Structure

The report follows this section order. All sections are required unless marked optional.

```
1. Executive Summary          — TL;DR for the user (written last, placed first)
2. Table of Contents          — Auto-generated from section headers
3. Contributors               — Every agent/person that participated, with role/status/contributions
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

## Report Lifecycle

The report has three phases: **Create**, **Update** (repeated), and **Finalize**.

### Phase 1: Create (Session Start)

When a session starts, check if a report exists for today:

```
File: ~/Library/CloudStorage/GoogleDrive-*/My Drive/Documents/YYYY-MM-DD-session-report.md
```

> **Path resolution**: Use `ls -d ~/Library/CloudStorage/GoogleDrive-*/My\ Drive/Documents/` to resolve the Google Drive path. If Google Drive is not available, fall back to `~/Documents/`.

- **If no report exists** → Create it from the template structure (see [Report Structure](#report-structure)). Populate the contributors section. Leave all other sections as empty tables/placeholders.
- **If a report already exists** (e.g., resumed session, multiple sessions in one day) → Read it. Do NOT overwrite. Proceed to Phase 2.

**Who creates**: The lead agent or orchestrator at session start. For solo agents, create it yourself.

### Phase 2: Incremental Updates (Throughout the Day)

Each contributor is responsible for noting their own work in the report as they complete it. This is not optional — it's part of task completion. A task is not done until the report reflects it.

**Update cadence**: The report should be updated after every meaningful deliverable — each task completion, each PR created or merged, each commit pushed, each failure logged. The goal is a continuously accurate document, not a batch dump at the end of the day.

#### What Each Role Updates

| Role                  | What to add                                              | When                               |
| --------------------- | -------------------------------------------------------- | ---------------------------------- |
| **Software Engineer** | Commits (hash, message, repo), PRs created/merged        | After each commit or PR action     |
| **AI Agent Eng**      | Failures logged, rules/behaviors created, review results | After each failure entry or review |
| **PM**                | Issues created/closed, task status changes               | After each issue batch or audit    |
| **Docs Writer**       | Docs updated, contradictions found                       | After each docs task               |
| **Researcher**        | Research reports saved, key findings                     | After each research deliverable    |
| **QA**                | Defects found, test results, QA reports                  | After each QA pass                 |
| **Ops**               | Pipeline fixes, release actions, infra changes           | After each ops task                |
| **Solo Agent**        | All of the above, as applicable                          | After each meaningful deliverable  |

#### Update Rules

1. **Append, never overwrite**: Add new rows to existing tables. Never replace content another agent wrote.
2. **Use the right section**: Commits go in Section 5, issues in Section 6, failures in Section 8. Don't dump everything in one place.
3. **Include links immediately**: Every commit hash, issue number, and PR must be a clickable link when first added. Don't leave "will link later" placeholders.
4. **Keep metrics approximate until finalization**: Section 9 (Metrics) can use `~` prefixed numbers during the day. Exact counts come in Phase 3.
5. **Conflict resolution**: If two agents update the same section simultaneously, the later writer must read the current state first and merge, not overwrite.
6. **Update immediately, not later**: Update the report as part of the task itself — not as a separate follow-up step. If you just created a PR, add it to the report before moving to your next task.

#### Batched Update Pattern (Exception Only)

When a burst of closely related deliverables happens in rapid succession (e.g., 5 commits in 10 minutes on the same PR), batching is acceptable as an exception:

```
# After completing a logical unit of work (e.g., a PR iteration):
1. Read the report's current state for your section
2. Append your new entries
3. Update the report file
```

The default is to update after each deliverable. Only batch when individual updates would be redundant (e.g., multiple commits that will be summarized together anyway). When in doubt, update immediately.

### Phase 3: Finalize (End of Session)

At session end, the report transitions from a living document to a reviewed deliverable.

#### Step 3a: Compile and Validate

The lead agent (or whoever is designated) does a full pass:

- Verify all sections have content (no empty placeholders remaining)
- Cross-reference commit counts against `git log` for each repo
- Verify all issues listed match `gh issue list` output
- Ensure all PRs are listed with correct state
- Check that failure descriptions match the failure log
- Fill in the timeline from commit timestamps
- Calculate exact metrics for Section 9

#### Step 3b: Review for Accuracy

Cross-reference:

- Commit hashes, failure descriptions, and issue states against source data
- Identify missing failures, untracked action items, or uncredited work
- Verify contributions are correctly attributed
- Draft or co-write the executive summary

**Review output**: Save to `.claude/tmp/session-report-review.md`.

#### Step 3c: Review for Quality

- Writing quality: section titles match content, consistent terminology
- Structure: all sections present, table of contents accurate
- Links: all URLs clickable, all references resolvable
- No placeholder text remaining, metrics match actual counts

#### Step 3d: Finalize and Deliver

- Incorporate all review feedback
- Do a final pass to confirm accuracy
- Deliver to the user

## Formatting Rules

### Links

Every reference MUST be a clickable markdown link:

```markdown
<!-- GOOD -->

[PR #164](https://github.com/nsheaps/ai-mktpl/pull/164)
[ai-mktpl #59](https://github.com/nsheaps/ai-mktpl/issues/59)
[`af6f0bf6`](https://github.com/nsheaps/ai-mktpl/commit/af6f0bf6)

<!-- BAD -->

PR #164
ai-mktpl #59
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

## Contributors Section Format

Each contributor entry includes:

| Field     | Description                              |
| --------- | ---------------------------------------- |
| Name / ID | Agent name or person's name              |
| Role      | One-line description                     |
| Started   | When work began (timestamp or session #) |
| Finished  | How/when work ended                      |
| Status    | Successful / Failed / Partial            |

Followed by: Notable Contributions (bulleted), Key Artifacts (file paths), Failures Attributed.

**For agent teams**: Include agent type (general-purpose, Bash, team-lead, etc.), model, CWD, and tmux pane if applicable. Sub-agents (Task tool agents that run to completion) should be listed separately with a note that they are not persistent team members.

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
| `~/.claude/teams/{team-name}/config.json`            | Agent roster, IDs, pane assignments (agent teams only)        |
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

| Pitfall                                            | Fix                                                                     |
| -------------------------------------------------- | ----------------------------------------------------------------------- |
| Links not clickable (plain text references)        | Every issue, PR, and commit must be a markdown link                     |
| "Key commits" shown but full log missing           | Always include complete commit log as appendix                          |
| Internal Task references in report                 | Map all `Task #NNN` to GitHub Issue URLs                                |
| No issue state differentiation                     | Query `state_reason` and show completed vs not_planned                  |
| Executive summary has wrong counts                 | Verify totals by counting actual data, not estimating                   |
| Valuable `.claude/tmp/` artifacts not preserved    | Move important artifacts to `docs/research/` before session ends        |
| Commit count mismatch between summary and appendix | Count from the appendix, update summary to match                        |
| Section titles don't match content                 | "Work Delivered" = commits, "GitHub Issues" = issues                    |
| Report generated only at end of session            | Use incremental updates throughout; end-of-session is just finalization |
| All work written by one person                     | Each contributor notes their own work; compiler validates at end        |
| Overwrote another contributor's entries            | Always read current state before writing; append, never replace         |

## Output Locations

1. **Primary**: `~/Library/CloudStorage/GoogleDrive-*/My Drive/Documents/YYYY-MM-DD-session-report.md`
2. **Fallback**: `~/Documents/YYYY-MM-DD-session-report.md` (if Google Drive is unavailable)
3. **Status file**: `.claude/tmp/report-update-status.md` — tracks what's been incorporated

## Executive Summary Guidelines

The executive summary is written last (after all data is gathered) but placed first in the report.

**Structure**:

1. **Opening line**: Who worked, duration, scope (e.g., "A 10-agent team ran for ~5 hours across 5 repos" or "Solo session: ~3 hours across 2 repos")
2. **Headline deliverable**: The single most important thing shipped, with link
3. **By the numbers**: Commits, issues, PRs, releases, failures — all exact counts
4. **What worked well**: 3-4 bullets with specific evidence
5. **Where we fell short**: 3-4 bullets, honest, with failure numbers
6. **Assessment**: One paragraph — honest take on the session's outcomes

**Tone**: Factual, evidence-based, honest. Not a sales pitch. The numbers and quality speak for themselves. Acknowledge rough edges directly.
