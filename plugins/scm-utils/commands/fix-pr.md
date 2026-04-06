---
name: fix-pr
description: >
  DEPRECATED: This skill is moving to the sdlc-utils plugin. Use the sdlc-utils:review skill instead.
  Fix or update the PR description for the current branch to follow best practices.
argument-hint: "[optional: PR number or URL]"
allowed-tools: Bash, Read, Grep, Glob
---

> **DEPRECATED:** This skill is moving to the sdlc-utils plugin. Use the `/sdlc-utils:review` skill instead.

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
