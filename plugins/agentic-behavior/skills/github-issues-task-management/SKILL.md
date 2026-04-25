---
name: github-issues-task-management
description: >
  This skill should be used when organizing work via GitHub Issues and Projects,
  creating project boards, managing milestones, or when transitioning from
  Discord thread-based tracking to GitHub-native tracking. Trigger phrases:
  "set up projects", "create a project board", "organize issues", "milestone
  planning", "what issues need attention", "consolidate tickets".
---

# GitHub Issues Task Management

GitHub Issues and Projects are the canonical system for tracking work. Discord
threads are supplementary communication channels, not the source of truth for
task status or assignments.

## Core Principles

1. **GitHub Issues are canonical.** Every significant work item needs a GitHub
   Issue. If it is not in GitHub Issues, it is not tracked.
2. **Consolidate, don't fragment.** Prefer fewer, broader issues over many
   narrow ones. A single issue for "implement feature X" is better than five
   issues for each sub-task unless the sub-tasks will be worked independently
   by different people or across different PRs.
3. **Discord supplements, not replaces.** Discord threads are for real-time
   discussion, status pings, and coordination. The issue is where decisions,
   acceptance criteria, and resolution are recorded.
4. **Link everything.** PRs link to issues. Issues link to project boards.
   Cross-repo references use full `owner/repo#N` format.

## Issue Lifecycle

### Creating Issues

Every issue must have:

- **Clear title** -- action-oriented, specific (not "Fix stuff")
- **Body with context** -- what, why, and acceptance criteria
- **Labels** -- at minimum a type label

Use the `issue-management` skill for the mechanics of creating, searching, and
updating issues via `gh` CLI. This skill covers the methodology.

### Linking PRs to Issues

Add magic phrases to the PR body to auto-close issues on merge:

```markdown
Fixes #42
Fixes nsheaps/ai-mktpl#15
Closes #7
```

Use `Fixes` for bug fixes, `Closes` for features/enhancements. For cross-repo
links, always use the full `owner/repo#N` format.

### Closing Issues

Issues close automatically when a linked PR merges. If closing manually, always
include a comment explaining resolution and referencing the relevant commit or
PR.

## Labels

Labels vary by project. Always conform to whatever the project's `.github/labels.yaml`
defines as the single source of truth. The categories below are common conventions.

### Priority Labels

Common conventions include `p0`/`p1`/`p2`/`p3` or `priority:high`/`priority:low`.
Check the project's `.github/labels.yaml` for the actual label names and use those.

| Concept  | Meaning                                  |
| -------- | ---------------------------------------- |
| Critical | Blocking all other work, fix immediately |
| High     | Should be resolved this sprint/cycle     |
| Normal   | Important but not urgent                 |
| Low      | Nice to have, backlog                    |

### Type Labels

Common type labels (exact names may differ per project):

| Concept     | Meaning                               |
| ----------- | ------------------------------------- |
| bug         | Something is broken                   |
| enhancement | Improvement to existing functionality |
| chore       | Maintenance, refactoring, tooling     |
| question    | Needs discussion or clarification     |

### Status Labels (optional)

Use sparingly -- GitHub Projects board columns often replace these:

| Concept      | Meaning                        |
| ------------ | ------------------------------ |
| needs-triage | Not yet prioritized            |
| blocked      | Waiting on external dependency |
| in-progress  | Actively being worked          |

## GitHub Projects

### When to Use Projects

- Organizing work across multiple repos
- Tracking milestones with multiple constituent issues
- Providing stakeholder visibility into progress
- Sprint or cycle planning

### Project Board Setup

```bash
# Create a project (org-level)
gh project create --owner nsheaps --title "Milestone: Feature X"

# Add an issue to a project
gh project item-add PROJECT_NUMBER --owner nsheaps --url https://github.com/nsheaps/repo/issues/42
```

### Board Columns

Standard column layout:

| Column      | Purpose                  |
| ----------- | ------------------------ |
| Backlog     | Triaged but not started  |
| In Progress | Actively being worked    |
| In Review   | PR open, awaiting review |
| Done        | Merged and verified      |

## Consolidation Strategy

When transitioning from fragmented tracking (many small Discord threads, many
narrow issues) to consolidated GitHub tracking:

### Step 1 -- Audit existing issues

```bash
gh issue list --repo owner/repo --state open --limit 100
```

### Step 2 -- Identify duplicates and related issues

Group issues that track the same feature, bug, or initiative. Look for:

- Same root cause described differently
- Sub-tasks that belong under a parent issue
- Issues that were superseded by newer ones

### Step 3 -- Consolidate

- Close duplicates with a comment linking to the canonical issue
- Merge sub-tasks into a parent issue (add as checklist items in the body)
- Transfer context from Discord threads into issue comments

### Step 4 -- Organize into project

- Create or update the relevant GitHub Project board
- Add all canonical issues to the board
- Set priorities and assignments

## Cross-Repo Issue Linking

When work spans multiple repos, always use full references:

```markdown
Related to nsheaps/agents#12
Blocked by nsheaps/ai-mktpl#45
Fixes nsheaps/ai-mktpl#15
```

Short references (`#N`) only work within the same repo. Cross-repo references
require `owner/repo#N`.

## Relationship to Other Skills

| Skill / Rule                                 | Scope                                                                    |
| -------------------------------------------- | ------------------------------------------------------------------------ |
| `issue-management`                           | Mechanics: how to create, search, update, close issues via CLI           |
| `github-issues-task-management` (this skill) | Methodology: how to organize work, manage projects, consolidate tracking |
| `agentic-behavior/rules/work-tracking.md`    | Thread-side discipline: linking, ownership, and milestone coordination   |

## Anti-Patterns

| Anti-Pattern                                          | Instead                                                |
| ----------------------------------------------------- | ------------------------------------------------------ |
| Tracking work only in Discord threads                 | Create a GitHub Issue; use Discord for discussion      |
| One issue per tiny sub-task                           | Consolidate into a parent issue with a checklist       |
| Short-form references across repos (`#N`)             | Use `owner/repo#N` for cross-repo links                |
| No labels on issues                                   | Add at least type + priority labels                    |
| Closing issues without explanation                    | Comment with resolution and link to PR/commit          |
| Using issue body as a living document without history | Use comments for updates; keep body as canonical state |

## References

- [GitHub Issues documentation](https://docs.github.com/en/issues)
- [GitHub Projects documentation](https://docs.github.com/en/issues/planning-and-tracking-with-projects)
- [`issue-management` skill](../issue-management/SKILL.md) -- CLI mechanics for issue operations
- [`gh` CLI skill](../../../github/skills/gh/SKILL.md) -- full gh CLI reference
