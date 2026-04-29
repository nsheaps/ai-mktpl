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
| `plugins`                     | Plugin source code              | `~/src/nsheaps/ai-mktpl/plugins/...`                              |
| `marketplace`                 | The AI config marketplace repo  | `~/src/nsheaps/ai-mktpl/...`                                      |

**Note:** If scope is obvious from context (e.g., correcting a slash command behavior), infer it. Otherwise, ask the user.

## Process

You MUST follow these steps in order:

### Step 1: Reflect and Understand

Before doing anything else, document these 5 items concretely:

1. **What the handler told you that you did wrong** — Quote or paraphrase their correction (`$ARGUMENTS`)
2. **What you think you did wrong** — Your own understanding, in your own words
3. **How you got there** — Root cause analysis: what decisions or assumptions led to the mistake?
4. **How you should have gotten to the correct solution** — The right path you should have followed
5. **The correct solution itself** — What the expected output/behavior should have been

**If you're unsure about any of these items, use the AskUserQuestion tool to clarify before proceeding.**

### Step 2: Determine Scope

Parse the arguments to determine scope:

- If first word matches a scope keyword (case-insensitive), use that scope
- If scope is obvious from context (e.g., the correction is about a slash command you just wrote), infer it
- If scope is unclear, ask the user using AskUserQuestion with options for relevant scopes

### Step 3: Review Existing Rules

**ALWAYS review ALL sources to determine where existing rules lie, regardless of where the correction will be made:**

1. **Prefer capturing functionality in reusable plugins** in https://github.com/nsheaps/ai-mktpl
2. **Some changes may be more functional than claude-code related**, and may live in the agents monorepo https://github.com/nsheaps/agents
3. **Other configurations may exist in repos that share configs and rulesets, like organization configs** which might be located at https://github.com/nsheaps/.org
4. **Consider agent configs as well, which act as user-configs when running the agent harness** agents like [jack](https://github.com/nsheaps/.ai-agent-jack), [alex](https://github.com/nsheaps/.ai-agent-alex), [henry](https://github.com/nsheaps/.ai-agent-henry) have configurations built from plugins and shared code, so opt to keep it re-useable, even if it is unique to our set of agents.
5. **Still, if there's reason to be project specific, you can add changes to project configs** to capture requirements like linting and rules specific to folders.
6. CRITICAL: While possible, avoid directly making changes to the user config, most sessions will want to be run differently. Few exceptions exist for this, like setting up proxy info, or base level permissions allow/deny (which can be set by plugins) and other important settings.

Identify:

- Are there existing plugins, hooks, rules, skills, documentation, about this behavior?
- If yes, why weren't they followed?
- Are there conflicting definitions? **If so, STOP and ask the user what to do about the conflict.**
  - conflicting can be inter-plugin or intra-plugin. 

### Step 4: Plan and Execute the Correction

Analyse your collected data on what went wrong. use the issue-management skill to document the failure to learn from it further.

Based on your analysis:

1. **Contribution priority order** — apply corrections in this order of preference (for internal to plugins, the same priority order applies sans the plugins-first comment):
   - **PLUGINS first** — shared plugin source, benefits all agents using the plugin
   - **HOOKS second** — programmatic execution always wins over natural language execution
   - **AGENTS third** — making an entire task delegateable is great for context preservation
   - **SKILLS fourth** — task-specific how-to documentation that can be shared between agents
   - **RULES fifth** — fallback if neither plugin nor skill fits

2. **Determine the best place for the rule:**

   | If the correction is...          | Put it in...                                                      |
   | -------------------------------- | ----------------------------------------------------------------- |
   | General user behavior            | a re-usable plugin that exists or will be created                 |
   | Project-specific                 | `<git-root>/.../CLAUDE.md` or `<git-root>/.claude/rules/*.md`     |
   | About a slash command            | A skill to replace the slash command                              |
   | About a skill                    | The skill's `SKILL.md`                                            |
   | About a plugin                   | The plugin source in `~/src/nsheaps/ai-mktpl/plugins/...`         |
   | Agent behavior                   | henry, jack, or alex's repo (for example)                         |
   | Repo contribution rules          | `~/src/nsheaps/ai-mktpl/.claude/rules/*.md` (Claude-specific)     |

3. **Write the correction:**
   - Be specific and actionable
   - Use clear, imperative language
   - Include context for why (prevents similar mistakes)
   - **NEVER write to `*.local.md` files** - these are personal and not saved

4. **Structure appropriately:**
   - If adding to CLAUDE.md: find the appropriate section or create one
   - If creating a new rule file: use descriptive filename in appropriate `rules/` directory
   - Keep rules focused and organized

5. **Review your changes:**
   - Re-read what you wrote
   - Verify it will actually prevent the behavior
   - Ensure it doesn't conflict with existing rules

### Step 5: Ensure Changes Are Committed

**CRITICAL: All changes must end up committed somewhere.**

| Scope                       | Commit Strategy                                                                                                                                              |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `user`                      | Changes go to `~/.claude/...` immediately. Source of truth is `~/src/nsheaps/ai-mktpl/.ai/rules/`. Ask user if they want changes synced there (requires PR). |
| `project`                   | Remind user to commit changes to the project repo                                                                                                            |
| `skills` (previously `slash-commands`) | If in `~/.claude/...`, ask about syncing to `~/src/nsheaps/ai-mktpl/...`                                                                                     |
| `plugins` / `marketplace`   | Changes are in `~/src/nsheaps/ai-mktpl/...`. Create a PR and assign to user.                                                                                 |

**Directory Structure in `~/src/nsheaps/ai-mktpl/`:**

- `.claude/rules/` - Rules for working on this repo (Claude-specific)
- `.ai/rules/` - User behavior rules that sync to user's config (AI-agnostic, can be used by other AI tools)

When making changes to `~/src/nsheaps/ai-mktpl/...`:

1. Check current git status
2. Create a feature branch if not already on one
3. Stage and commit changes
4. Push and create PR using `gh pr create --assignee <user>`
5. Open PR in browser with `gh pr view --web`

### Step 6: Correct the Original Work

Go back to the work you just did and fix what was done incorrectly:

- Identify the specific changes that were wrong
- Undo or correct those changes
- Verify the correction aligns with what the user wanted

## Important Notes

- **Always commit:** Changes must always end up committed somewhere. User config changes should be synced to `~/src/nsheaps/ai-mktpl/.ai/rules/` as source of truth.

- **Never guess:** If uncertain about the scope or the correction, always ask the user.

- **Best practices first:** Even if current rules don't follow best practices, your correction should follow them if it works.

- **Document the "why":** Include brief context in the rule so future AI instances understand the reasoning.

- **AI-agnostic rules:** When the behavior applies to any AI assistant (not just Claude), put it in `.ai/rules/` instead of `.claude/rules/`.

- **Use claude-code-guide agent:** You can and should consider using the `claude-code-guide` agent to help you with any changes needed to Claude Code configuration files.

- **Work on main branch:** When correcting behavior, make the change directly on the main branch and `/commit` and push after completing the correction.

## Example Corrections

### Example 1: Don't commit without asking (user scope)

```
/correct-behavior user don't commit unless I tell you
```

Would add to `~/.claude/CLAUDE.md` and offer to sync to `~/src/nsheaps/ai-mktpl/.ai/rules/`:

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
> - MARKETPLACE (shared with others via ~/src/nsheaps/ai-mktpl)
