# GitHub Issues for Task Management

This repository uses GitHub Issues as the primary task management system.

## When to Create Issues

Create GitHub issues for:

- Bugs discovered during development
- Feature requests and enhancements
- Tasks that cannot be completed in the current session
- Work items that need tracking across multiple sessions
- Items requiring user input or review before proceeding

Do NOT create issues for:

- Tasks you can complete immediately
- Temporary notes (use scratch files instead)

## Issue Structure

**Title**: Clear, actionable description starting with a verb

- Good: "Add validation for plugin manifest files"
- Bad: "Validation issue" or "Plugin stuff"

**Body**: Include context an AI agent needs to pick up the work:

- What needs to be done
- Why it matters
- Acceptance criteria (if applicable)
- Related files or code references

## Label Management

**CRITICAL:** All labels are defined in `.github/labels.yaml` and synced automatically by the `sync-labels.yml` workflow. This is the single source of truth.

- **NEVER** create labels inline in workflows, scripts, or via `gh label create`
- To add a new label: add it to `.github/labels.yaml` — it will be synced on merge to main
- The sync workflow uses `skip-delete: true`, so labels not in the YAML are preserved

## Labels for Workflow State

Use labels to indicate issue state beyond open/closed:

| Label                 | Purpose                                   |
| --------------------- | ----------------------------------------- |
| `status:in-progress`  | Actively being worked on                  |
| `status:blocked`      | Cannot proceed - see comments for blocker |
| `status:needs-review` | Work complete, awaiting human review      |
| `status:on-hold`      | Intentionally paused, not abandoned       |

## Labels for Issue Type

| Label           | Purpose                           |
| --------------- | --------------------------------- |
| `bug`           | Something isn't working correctly |
| `enhancement`   | New feature or improvement        |
| `documentation` | Documentation updates needed      |
| `chore`         | Maintenance, refactoring, cleanup |

## Labels for Priority

| Label           | Purpose                          |
| --------------- | -------------------------------- |
| `priority:high` | Address soon, blocks other work  |
| `priority:low`  | Nice to have, do when convenient |

## Working with Issues

**Starting work on an issue:**

```bash
# Add in-progress label
gh issue edit <number> --add-label "status:in-progress"
```

**When blocked:**

```bash
# Add blocked label and comment explaining why
gh issue edit <number> --add-label "status:blocked"
gh issue comment <number> --body "Blocked: <reason>"
```

**Completing work:**

```bash
# Remove status labels, close with comment
gh issue edit <number> --remove-label "status:in-progress"
gh issue close <number> --comment "Completed in <commit/PR>"
```

## Searching Issues

```bash
# Find issues ready to work on
gh issue list --label "enhancement" --no-label "status:in-progress,status:blocked"

# Find blocked issues
gh issue list --label "status:blocked"

# Find issues needing review
gh issue list --label "status:needs-review"
```

## AI Agent Guidelines

1. **Check for existing issues** before starting new work - someone may have already filed it
2. **Update issue status** when starting/stopping work so others know the state
3. **Comment on progress** for long-running tasks so context isn't lost
4. **Link commits/PRs** to issues using "Fixes #N" or "Related to #N"
5. **Create issues proactively** when you discover problems you can't address immediately

## Bug Reports Require Verification

**CRITICAL:** Before creating a bug report issue, you MUST verify the bug actually exists.

**Required before filing a bug:**

1. **Verify actual state** - Read the file/check the system state yourself
2. **Check your own actions** - Did you actually do what you think you did?
3. **Investigate root cause** - Is it really a bug, or missing configuration?
4. **Include evidence** - Show actual file contents, git history, error messages

**Do NOT create bug issues based on:**

- Assumptions about what "must have happened"
- Memory of what you think you did earlier
- Guesses about tooling behavior

**Example of a BAD bug report:**

> "CI reverted my version bump" - based on seeing an old version, without checking git history or actual commits

**Example of a GOOD bug report:**

> "Version bump not applied. Evidence:
>
> - Committed in abc123 with version 0.1.0
> - Current file shows 0.0.1 after CI run def456
> - CI logs show [specific output]"

See also: `.ai/rules/verify-before-blaming.md`
