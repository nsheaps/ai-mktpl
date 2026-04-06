---
name: fix-pr
description: >
  Fix PR metadata only: review and correct the PR title and body to match formatting standards
  from making-great-prs. Does NOT review code, fix CI, or iterate on quality — it only touches
  the PR description. Use when the PR body is stale, malformatted, or missing sections.
argument-hint: "[optional: PR number or URL]"
allowed-tools: Bash, Read, Grep, Glob
---

## When to Use This Skill

- The PR **title or body** needs fixing (stale, malformatted, missing Summary/Test plan)
- You pushed new commits and need to **update the PR description** to reflect them
- The handler says "fix the PR", "update the PR body", or "the PR description is wrong"

## When NOT to Use This Skill

- You need to **review code quality** (use `scm-utils:code-review`)
- You want to **iteratively improve code** to meet a quality bar (use `scm-utils:iterate-until-good`)
- You need to **fix CI failures or address review comments** (use `fix-pr:relentlessly-fix`)
- You need to **create a brand new PR** (use `scm-utils:making-great-prs`)

## Related Skills

| Skill                          | Relationship                                                                                         |
| ------------------------------ | ---------------------------------------------------------------------------------------------------- |
| `scm-utils:making-great-prs`   | The standards this skill evaluates against; use making-great-prs for creation, fix-pr for correction |
| `scm-utils:code-review`        | Reviews code; fix-pr fixes PR metadata only                                                          |
| `scm-utils:iterate-until-good` | Quality gate for code; fix-pr is for PR description only                                             |
| `fix-pr:relentlessly-fix`      | Reactive CI/review fixer; fix-pr only touches the PR title and body                                  |

---

# Fix PR Description

Review and fix the pull request description for the current branch, ensuring it follows the formatting and content standards from the `making-great-prs` skill.

## Pre-fetched Context

Current branch: !`git branch --show-current 2>/dev/null || echo "(not in a git repo)"`

## Step 1: Identify the PR

Based on **$ARGUMENTS**:

- **No arguments**: Find the open PR for the current branch
- **PR number or URL provided**: Use the specified PR

## Step 2: Read Current PR State

Fetch the current PR details (title, body, commits, changed files) so you understand:

- What the PR currently says
- What files were actually changed
- What the commit history says about the changes

## Step 3: Evaluate and Fix

Check the PR against these standards (from the `making-great-prs` skill):

### Title

- Under 70 characters
- Starts with a verb (Add, Fix, Update, Refactor, etc.)
- Matches conventional commit style when applicable

### Body Structure

- Has a `## Summary` section with bullet points describing what changed and why
- Has a `## Test plan` section with checkbox items for verification
- Includes a session link if available
- Uses proper markdown formatting with real newlines (no literal `\n`)

### Body Content

- Summary accurately reflects ALL commits on the branch, not just the latest
- Test plan items are specific and actionable
- No placeholder text or template remnants

## Step 4: Update the PR

Update the PR title and/or body with the corrected content. Show the user what changed.

## Usage Examples

```bash
/fix-pr              # Fix PR for current branch
/fix-pr 300          # Fix PR #300
```
