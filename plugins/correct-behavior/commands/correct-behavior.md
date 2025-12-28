---
name: correct-behavior
description: Correct a behavior mistake I made and update rules to prevent recurrence
argument-hint: "[SCOPE] <description of what I did wrong>"
allowed-tools: Read, Glob, Grep, Edit, Write, Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(git checkout:*), Bash(gh pr:*), Bash(ls:*), Bash(pwd:*), Bash(mkdir:*), AskUserQuestion
---

# Behavior Correction Command

This command helps correct AI behavior mistakes and ensures they don't happen again by updating the appropriate rules files.

## Context

**User's correction:** $ARGUMENTS

## Supported Scopes

| Scope                         | Description                     | Location                                                          |
| ----------------------------- | ------------------------------- | ----------------------------------------------------------------- |
| `user`                        | Personal rules for all projects | `~/.claude/CLAUDE.md` or `~/.claude/rules/*.md`                   |
| `project`                     | Rules for the current project   | `<git-root>/.claude/CLAUDE.md` or `<git-root>/.claude/rules/*.md` |
| `slash-commands` / `commands` | User's slash commands           | `~/.claude/commands/*.md`                                         |
| `skills`                      | User's skills                   | `~/.claude/skills/*/SKILL.md`                                     |
| `plugins`                     | Plugin source code              | `~/src/nsheaps/ai/plugins/...`                                    |
| `marketplace`                 | The AI config marketplace repo  | `~/src/nsheaps/ai/...`                                            |

**Note:** If scope is obvious from context (e.g., correcting a slash command behavior), infer it. Otherwise, ask the user.

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

- If first word matches a scope keyword (case-insensitive), use that scope
- If scope is obvious from context (e.g., the correction is about a slash command you just wrote), infer it
- If scope is unclear, ask the user using AskUserQuestion with options for relevant scopes

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

4. **Marketplace repo (if relevant):**
   - `~/src/nsheaps/ai/.claude/rules/*.md` - rules for modifying the repo itself
   - `~/src/nsheaps/ai/.ai/rules/*.md` - user behavior rules (AI-agnostic, syncs to user config)
   - `~/src/nsheaps/ai/plugins/*/commands/*.md` - plugin commands

Identify:

- Are there existing rules about this behavior?
- If yes, why weren't they followed?
- Are there conflicting rules? **If so, STOP and ask the user what to do about the conflict.**

### Step 5: Plan and Execute the Correction

Based on your analysis:

1. **Determine the best place for the rule:**

   | If the correction is...          | Put it in...                                                      |
   | -------------------------------- | ----------------------------------------------------------------- |
   | General user behavior            | `~/.claude/CLAUDE.md` or `~/.claude/rules/*.md`                   |
   | Project-specific                 | `<git-root>/.claude/CLAUDE.md` or `<git-root>/.claude/rules/*.md` |
   | About a slash command            | The command file itself                                           |
   | About a skill                    | The skill's `SKILL.md`                                            |
   | About a plugin                   | The plugin source in `~/src/nsheaps/ai/plugins/...`               |
   | User behavior (shared/backed up) | `~/src/nsheaps/ai/.ai/rules/*.md` (AI-agnostic)                   |
   | Repo contribution rules          | `~/src/nsheaps/ai/.claude/rules/*.md` (Claude-specific)           |

2. **Write the correction:**
   - Be specific and actionable
   - Use clear, imperative language
   - Include context for why (prevents similar mistakes)
   - **NEVER write to `*.local.md` files** - these are personal and not saved

3. **Structure appropriately:**
   - If adding to CLAUDE.md: find the appropriate section or create one
   - If creating a new rule file: use descriptive filename in appropriate `rules/` directory
   - Keep rules focused and organized

4. **Review your changes:**
   - Re-read what you wrote
   - Verify it will actually prevent the behavior
   - Ensure it doesn't conflict with existing rules

### Step 6: Ensure Changes Are Committed

**CRITICAL: All changes must end up committed somewhere.**

| Scope                       | Commit Strategy                                                                                                                                        |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `user`                      | Changes go to `~/.claude/...` immediately. Source of truth is `~/src/nsheaps/ai/.ai/rules/`. Ask user if they want changes synced there (requires PR). |
| `project`                   | Remind user to commit changes to the project repo                                                                                                      |
| `slash-commands` / `skills` | If in `~/.claude/...`, ask about syncing to `~/src/nsheaps/ai/...`                                                                                     |
| `plugins` / `marketplace`   | Changes are in `~/src/nsheaps/ai/...`. Create a PR and assign to user.                                                                                 |

**Directory Structure in `~/src/nsheaps/ai/`:**

- `.claude/rules/` - Rules for working on this repo (Claude-specific)
- `.ai/rules/` - User behavior rules that sync to user's config (AI-agnostic, can be used by other AI tools)

When making changes to `~/src/nsheaps/ai/...`:

1. Check current git status
2. Create a feature branch if not already on one
3. Stage and commit changes
4. Push and create PR using `gh pr create --assignee <user>`
5. Open PR in browser with `gh pr view --web`

### Step 7: Correct the Original Work

Go back to the work you just did and fix what was done incorrectly:

- Identify the specific changes that were wrong
- Undo or correct those changes
- Verify the correction aligns with what the user wanted

## Important Notes

- **Always commit:** Changes must always end up committed somewhere. User config changes should be synced to `~/src/nsheaps/ai/.ai/rules/` as source of truth.

- **Never guess:** If uncertain about the scope or the correction, always ask the user.

- **Best practices first:** Even if current rules don't follow best practices, your correction should follow them if it works.

- **Document the "why":** Include brief context in the rule so future AI instances understand the reasoning.

- **AI-agnostic rules:** When the behavior applies to any AI assistant (not just Claude), put it in `.ai/rules/` instead of `.claude/rules/`.

## Example Corrections

### Example 1: Don't commit without asking (user scope)

```
/correct-behavior user don't commit unless I tell you
```

Would add to `~/.claude/CLAUDE.md` and offer to sync to `~/src/nsheaps/ai/.ai/rules/`:

```markdown
- NEVER commit changes to git unless the user explicitly asks you to commit.
```

### Example 2: Project-specific API pattern

```
/correct-behavior project always use the ApiClient class for API calls
```

Would add to project's `.claude/CLAUDE.md` and remind user to commit.

### Example 3: Slash command fix (inferred scope)

```
/correct-behavior the commit command should always show a preview first
```

Would update `~/.claude/commands/commit.md` (or the plugin source) and offer to PR to marketplace.

### Example 4: Scope clarification needed

```
/correct-behavior stop adding unnecessary comments
```

Would prompt:

> This could apply in multiple places. Where should I add this rule?
>
> - USER (applies to all your projects)
> - PROJECT (just this codebase)
> - MARKETPLACE (shared with others via ~/src/nsheaps/ai)
