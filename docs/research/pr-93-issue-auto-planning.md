# PR #93: Issue Creation Auto-Planning

Research document capturing learnings from PR review and feedback.

**PR**: https://github.com/nsheaps/.ai/pull/93
**Branch**: `claude/issue-creation-auto-planning`
**Related Issue**: #92

---

## Purpose

Implement auto-planning for new GitHub issues. When an issue is created, Claude should automatically convert it into a structured implementation plan.

---

## Current State (as of 0fb499d)

The PR has gone through multiple iterations with increasingly complex architecture. The latest feedback (2026-01-20T02:40) requests simplification.

### Files Changed

| File                                               | Purpose                                |
| -------------------------------------------------- | -------------------------------------- |
| `.ai/prompts/issue-planner-system.md`              | New planning prompt template           |
| `.ai/prompts/claude-agent-system.md`               | Updated agent prompt (envsubst format) |
| `.github/schemas/claude-agent-payload.schema.json` | Extended with `planning_context`       |
| `.github/actions/dispatch-claude-agent/action.yml` | New composite action                   |
| `.github/workflows/claude-agent.yaml`              | Simplified agent workflow              |
| `.github/workflows/claude-agent-mention.yaml`      | New mention trigger workflow           |
| `.github/workflows/claude-agent-new-issue.yaml`    | New issue trigger workflow             |

---

## Key Feedback from @nsheaps

### Final Direction (02:40:02Z)

> Ignore all the comments on here to try and follow it.

The workflows should be structured as:

#### 1. `claude-agent.yaml` (Agent Workflow)

- Triggered by `repository_dispatch`
- Receives **complete context** in the dispatch payload
- No `planning_context` schema - all variations should be in the prompt itself
- If prompt varies by key, that's the composite action's responsibility

#### 2. `dispatch-claude-agent` (Composite Action)

- Does **EVERYTHING** needed to create the dispatch:
  - Checkout repo
  - Run `github-app-auth` action
  - Build prompt with all context
  - Send repository dispatch
- Takes secrets for authentication as inputs
- Handles prompt variation (e.g., selecting template path)

#### 3. Trigger Workflow (Single workflow, multiple jobs)

- Should be "simple af"
- **Drop labels/replan for now** - simplify first
- Has ALL trigger conditions in `on:` block
- Each trigger type = separate job
- Must deduplicate when workflow creates multiple runs

**Two jobs for now:**

1. **mention** - When @claude is mentioned in PR/issue
   - Explicitly ignores `action == "opened"`
2. **new-issue** - When a new issue is created
   - Plans the issue first
   - If @claude mention exists with specific work request:
     - Post a comment with trigger phrase to hand off to mention workflow
     - Exit and let mention workflow handle the directed work

### Template Fix (02:40:39Z)

In `.ai/prompts/issue-planner-system.md`:

> The summary section MUST be at the end of the `<details>` block

Current structure is wrong:

```markdown
<details>
<summary>...</summary>
Content here
</details>
```

Should be:

```markdown
<details>
Content here
<summary>...</summary>
</details>
```

**Note**: Actually, HTML `<details>` requires `<summary>` to be the _first_ child. Need to clarify with user - this may be about the Analysis section's accordion structure.

---

## Architecture Diagram (Target)

```
┌─────────────────────────────────────────────────────────────┐
│                    Trigger Workflow                          │
│            (claude-agent-trigger.yaml)                       │
│                                                              │
│  on:                                                         │
│    issue_comment: [created]                                  │
│    pull_request_review_comment: [created]                    │
│    pull_request_review: [submitted]                          │
│    issues: [opened, assigned]                                │
│                                                              │
│  ┌─────────────────────┐    ┌─────────────────────┐         │
│  │   Job: mention      │    │  Job: new-issue     │         │
│  │                     │    │                     │         │
│  │ if: @claude in body │    │ if: action=opened   │         │
│  │ AND action!=opened  │    │                     │         │
│  └──────────┬──────────┘    └──────────┬──────────┘         │
└─────────────┼───────────────────────────┼───────────────────┘
              │                           │
              │  uses:                    │  uses:
              │  dispatch-claude-agent    │  dispatch-claude-agent
              ▼                           ▼
┌─────────────────────────────────────────────────────────────┐
│              dispatch-claude-agent action                    │
│                                                              │
│  Inputs:                                                     │
│    - app-id, private-key (for auth)                         │
│    - event context (issue/PR/comment info)                  │
│    - workflow-type (mention | new-issue)                    │
│                                                              │
│  Steps:                                                      │
│    1. Checkout repo                                          │
│    2. github-app-auth action                                 │
│    3. Build prompt (select template, interpolate)            │
│    4. repository_dispatch → claude-agent                     │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           │  repository_dispatch
                           │  event-type: claude-agent
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   claude-agent.yaml                          │
│                                                              │
│  on:                                                         │
│    repository_dispatch:                                      │
│      types: [claude-agent]                                   │
│                                                              │
│  - Receives full prompt in payload                           │
│  - Runs Claude Code with provided prompt                     │
│  - No conditional logic based on trigger type                │
└─────────────────────────────────────────────────────────────┘
```

---

## Double-Trigger Prevention

When a new issue contains `@claude`:

1. `new-issue` job runs (matches `issues.opened`)
2. `mention` job would also match, but has `if: action != 'opened'`
3. `new-issue` job:
   - Plans the issue first
   - Checks if @claude has specific work request
   - If yes: posts comment with `@claude <extracted request>`
   - This triggers `mention` job via `issue_comment.created`

---

## Schema Simplification

Remove `planning_context` from schema. The dispatch payload should be:

```json
{
  "prompt": "Full interpolated prompt with all context",
  "source": {
    "repo": "owner/repo",
    "issue_number": 123,
    "pr_number": null,
    "comment_id": null
  },
  "author": {
    "login": "username",
    "association": "OWNER"
  },
  "trigger": {
    "type": "issues",
    "action": "opened"
  },
  "content": {
    "title": "Issue title",
    "body": "Issue body"
  }
}
```

All differentiation (planning vs mention handling) is captured in the `prompt` field.

---

## Template Variables

Using `envsubst` format (`${VAR}`) instead of Jinja (`{{ var }}`).

**issue-planner-system.md variables:**

- `${REPO}` - Repository name
- `${ISSUE_NUMBER}` - Issue number
- `${ORIGINAL_ISSUE_BODY}` - Original issue text

**claude-agent-system.md variables:**

- `${REPO}` - Repository name
- `${PR_CONTEXT}` - PR info if applicable
- `${ISSUE_CONTEXT}` - Issue info if applicable
- `${AUTHOR}` - Trigger author
- `${PROMPT}` - The user's message/request

---

## Outstanding Tasks

1. **Simplify trigger workflow** - Single workflow with 2 jobs (mention, new-issue)
2. **Composite action does everything** - Including checkout and auth
3. **Remove `planning_context`** - All variation goes in prompt
4. **Fix template `<details>` structure** - Clarify correct order
5. **Drop labels/replan** - Simplify first, add back later

---

## References

- PR: https://github.com/nsheaps/.ai/pull/93
- Issue: https://github.com/nsheaps/.ai/issues/92
- CI/CD Conventions: `.claude/rules/ci-cd/conventions.md`
- Plugin Development: `.claude/rules/plugin-development.md`
