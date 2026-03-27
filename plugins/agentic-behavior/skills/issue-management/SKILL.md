---
name: issue-management
description: >
  Use this skill when the user says "make an issue", "create an issue",
  "file a bug", "this is a bug", "let's follow up later", "track this",
  "open a ticket", "create a ticket", "log this for later", "we need to
  fix this", "add to backlog", "make a task for", "file an enhancement",
  "create a feature request", or any phrase indicating that something
  should be tracked, logged, or followed up on in a ticketing system.
---

# Issue Management

Create, search, update, and link tickets across ticketing systems. The
canonical platform is GitHub Issues (via `gh` CLI), but the workflow is
designed to be system-agnostic. See [Platform-Specific Guides](#platform-specific-guides)
for implementation details per system.

## Core Principle: Deduplicate Before Creating

**ALWAYS search for existing issues before opening a new one.** Creating
duplicate tickets fragments context, confuses contributors, and wastes
triage time. Only create a new issue after verifying no matching issue
exists — open or recently closed.

---

## Deduplication Protocol

Run these steps in order before every `create` operation:

### Step 1 — Search the target repo

```bash
gh issue list --search "keywords from the topic" --repo owner/repo --state all --limit 20
```

Use 2–4 meaningful keywords from the issue topic. Include `--state all`
to catch recently closed issues that may need reopening.

### Step 2 — Search across the org

```bash
gh api graphql -f query='
  query($q: String!) {
    search(query: $q, type: ISSUE, first: 10) {
      nodes {
        ... on Issue {
          number title url state repository { nameWithOwner }
        }
      }
    }
  }
' -f q="keywords org:your-org-name"
```

Issues may live in a different repo from where you're currently working.
Search broadly — the right place to track something may not be obvious.

### Step 3 — Decide

| Search result       | Action                                                                          |
| ------------------- | ------------------------------------------------------------------------------- |
| Clear match (open)  | Comment on the existing issue with new context; do NOT create a duplicate       |
| Clear match (closed)| Evaluate: reopen with a comment, or reference it in a new issue if truly new   |
| Ambiguous match     | Ask: "Found `owner/repo#N` which looks related — update that one or create new?" |
| No match            | Create a new issue                                                              |

---

## Generic Operations

These operations map to every supported ticketing platform.

### Create a ticket

Required fields:
- **Title** — concise, action-oriented (e.g., "Fix: login redirects to 404 on mobile")
- **Body** — problem description, steps to reproduce (bugs), or acceptance criteria (features)
- **Labels** — at minimum, one type label (`bug`, `enhancement`, `question`)

Optional:
- **Assignee** — who should handle this
- **Milestone / sprint** — when it should be resolved
- **Linked issues** — what this relates to or blocks

### Search tickets

Search by: keywords, labels, assignee, status (open/closed/all), date range.
Always search with `--state all` unless you specifically want only open issues.

### Update a ticket

Updateable fields: title, body, labels (add/remove), assignee, milestone, status.
Use comments to add context without rewriting history.

### Close a ticket

Close with a comment explaining resolution. Reference the PR or commit
that resolved it when applicable.

### Link tickets

- **Blocks / is blocked by** — use body text: "Blocks #N" or "Blocked by #N"
- **Relates to** — use body text: "Related to owner/repo#N"
- **Fixes** — use in PR body: "Fixes #N" (auto-closes on merge in GitHub)

---

## Platform-Specific Guides

### GitHub Issues (current default)

Recall the `gh` skill for full CLI reference.

#### Create an issue

```bash
gh issue create \
  --repo owner/repo \
  --title "Bug: description of the problem" \
  --body "$(cat <<'EOF'
## Problem

Describe what's wrong and why it matters.

## Steps to Reproduce

1. Step one
2. Step two
3. Observe: ...

## Expected Behavior

What should happen.

## Actual Behavior

What actually happens.
EOF
)" \
  --label "bug"
```

For feature requests, swap `--label "bug"` for `--label "enhancement"`.

#### Add a comment to an existing issue

```bash
gh issue comment ISSUE_NUMBER --repo owner/repo --body "New context: ..."
```

#### Update labels or title

```bash
gh issue edit ISSUE_NUMBER --repo owner/repo \
  --add-label "priority:high" \
  --remove-label "needs-triage"

gh issue edit ISSUE_NUMBER --repo owner/repo --title "Updated title"
```

#### Reopen a closed issue

```bash
gh issue reopen ISSUE_NUMBER --repo owner/repo --comment "This regressed in v2.3"
```

#### Close an issue

```bash
gh issue close ISSUE_NUMBER --repo owner/repo --comment "Fixed in #PR_NUMBER"
```

#### Link to a PR

Add to the PR body (not the issue body):

```
Fixes owner/repo#ISSUE_NUMBER
```

GitHub auto-closes the issue when the PR merges.

### Linear

> Integration via the `linear-mcp-sync` plugin when available. This guide
> will be updated when that plugin ships. Until then, use GitHub Issues as
> the canonical tracker.

---

## Issue Body Templates

### Bug Report

```markdown
## Problem

[What is broken and what impact does it have?]

## Steps to Reproduce

1.
2.
3. Observe: ...

## Expected Behavior

[What should happen]

## Actual Behavior

[What actually happens]

## Environment

- Version/commit:
- OS/platform:
- Relevant config:

## Additional Context

[Logs, screenshots, related issues]
```

### Feature Request / Enhancement

```markdown
## Summary

[One-sentence description of the feature]

## Motivation

[Why is this needed? What problem does it solve? Who benefits?]

## Proposed Solution

[How should this work? What should the user experience be?]

## Alternatives Considered

[What other approaches were considered and why they were rejected]

## Acceptance Criteria

- [ ] Criterion one
- [ ] Criterion two

## Additional Context

[Mockups, related issues, external references]
```

---

## Anti-Patterns to Avoid

| Anti-Pattern                        | Instead                                                       |
| ----------------------------------- | ------------------------------------------------------------- |
| Creating without searching first    | Always run the deduplication protocol before creating         |
| Vague titles like "Fix bug"         | Use specific, actionable titles: "Fix: login 404 on mobile"   |
| Empty body or one-liner description | Include context, reproduction steps, or acceptance criteria   |
| Silently creating a duplicate       | Comment on the existing issue or ask the handler to decide    |
| Closing without explanation         | Always include a resolution comment referencing the fix       |

---

## References

- [GitHub Issues documentation](https://docs.github.com/en/issues)
- [`gh` CLI skill](../../../github/skills/gh/SKILL.md) — full gh CLI reference
- [Linear MCP sync plugin](../../linear-mcp-sync/) — future Linear integration
