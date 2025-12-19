---
name: correct-behavior
description: Correct a behavior mistake I made and update rules to prevent recurrence
argument-hint: "[USER|PROJECT] <description of what I did wrong>"
allowed-tools: Read, Glob, Grep, Edit, Write, Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*), Bash(ls:*), Bash(pwd:*), AskUserQuestion
---

# Behavior Correction Command

This command helps correct AI behavior mistakes and ensures they don't happen again by updating the appropriate rules files.

## Context

**User's correction:** $ARGUMENTS

## Process

You MUST follow these steps in order:

### Step 1: Reflect on Recent Work

Think carefully about:
- What task was I just working on?
- What was I supposed to do?
- What did I actually do?
- How did I get there?
- Did I stay on task or drift?

Document your reflection clearly before proceeding.

### Step 2: Understand the Correction

Analyze the user's correction (`$ARGUMENTS`) in context of your recent work:
- What specifically did I do wrong?
- Where did I start going awry?
- Was this a one-time mistake or a pattern?

**If you're unsure what you did wrong, use the AskUserQuestion tool to clarify before proceeding.**

### Step 3: Determine Scope

Parse the arguments to determine scope:
- If first word is `USER` (case-insensitive): correction applies to `~/.claude/` (user-level)
- If first word is `PROJECT` (case-insensitive): correction applies to project config (`.claude/` or `CLAUDE.md` in git root)
- If scope is not specified:
  - Ask the user which scope applies using AskUserQuestion
  - Default suggestion: USER for general behavior, PROJECT for project-specific patterns

### Step 4: Review Existing Rules

**ALWAYS review BOTH user and project rules, regardless of where the correction will be made:**

1. **User-level rules:**
   - `~/.claude/CLAUDE.md`
   - `~/.claude/rules/*.md` (if exists)

2. **Project-level rules:**
   - Find git root: `git rev-parse --show-toplevel`
   - Check: `<git-root>/CLAUDE.md` or `<git-root>/.claude/CLAUDE.md`
   - Check: `<git-root>/.claude/rules/*.md`
   - Check: `<git-root>/CLAUDE.local.md` (local only, don't modify)

3. **Related commands/skills:**
   - `~/.claude/commands/*.md`
   - `<git-root>/.claude/commands/*.md`
   - Check if behavior is controlled by a skill or command

Identify:
- Are there existing rules about this behavior?
- If yes, why weren't they followed?
- Are there conflicting rules? **If so, STOP and ask the user what to do about the conflict.**

### Step 5: Plan and Execute the Correction

Based on your analysis:

1. **Determine the best place for the rule:**
   - If it's a general behavior: user CLAUDE.md or user rules
   - If it's project-specific: project CLAUDE.md or project rules
   - If it affects a command/skill: consider updating that instead

2. **Write the correction:**
   - Be specific and actionable
   - Use clear, imperative language
   - Include context for why (prevents similar mistakes)
   - **NEVER write to `*.local.md` files** - these are personal and not saved

3. **Structure appropriately:**
   - If adding to CLAUDE.md: find the appropriate section or create one
   - If creating a new rule file: use descriptive filename in `.claude/rules/`
   - Keep rules focused and organized

4. **Review your changes:**
   - Re-read what you wrote
   - Verify it will actually prevent the behavior
   - Ensure it doesn't conflict with existing rules

### Step 6: Handle Slash Commands and Skills

If the behavior issue stems from a slash command or skill:
- **Ask the user before making changes to commands/skills**
- Consider if changes should also be made to `~/src/nsheaps/ai/...` plugins
- If changes are needed in plugins, offer to create a PR

### Step 7: Notify User of Changes

After making changes:

**For PROJECT scope:**
- Remind the user that changes need to be committed
- Show what files were modified

**For USER scope:**
- Ask if the change should also be made in `~/src/nsheaps/ai/...` for sharing/backup
- If yes, follow the PR workflow for that repo

### Step 8: Correct the Original Work

Go back to the work you just did and fix what was done incorrectly:
- Identify the specific changes that were wrong
- Undo or correct those changes
- Verify the correction aligns with what the user wanted

## Important Notes

- **Worktrees for PRs:** If making changes to `~/src/nsheaps/ai/...`, consider using a git worktree at `~/src/_worktrees/nsheaps/ai/<task-name>/` to keep changes separate. Use `gh` CLI to create the PR and assign it to the current user.

- **Never guess:** If uncertain about the scope or the correction, always ask the user.

- **Best practices first:** Even if current rules don't follow best practices, your correction should follow them if it works.

- **Document the "why":** Include brief context in the rule so future AI instances understand the reasoning.

## Example Corrections

### Example 1: Don't commit without asking
```
/correct-behavior USER don't commit unless I tell you
```
Would add to `~/.claude/CLAUDE.md`:
```markdown
- NEVER commit changes to git unless the user explicitly asks you to commit. Wait for explicit instruction like "commit this" or "make a commit".
```

### Example 2: Project-specific API pattern
```
/correct-behavior PROJECT always use the ApiClient class for API calls
```
Would add to project's `.claude/CLAUDE.md` or a rule file:
```markdown
- Always use the `ApiClient` class from `src/utils/api.ts` for all API calls. Do not use fetch or axios directly.
```

### Example 3: Scope clarification needed
```
/correct-behavior stop adding unnecessary comments
```
Would prompt:
> This could apply to all your projects or just this one. Should I add this rule at the USER level (applies everywhere) or PROJECT level (just this codebase)?
