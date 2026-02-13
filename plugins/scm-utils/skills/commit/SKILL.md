---
name: commit
description: Intelligently commit outstanding changes in logical, focused commits. Use this when you want to commit code using git.
argument-hint: [optional hint for skill]
---

NOTE: a slash command has been provided to the user for convenience. If you read this skill, you do not need to execute the command.

# Current branch status

!`git status`

## last 10 commits

!`git log --oneline -10`

# Intelligent Commit Process

You should commit outstanding changes by breaking them into logical, focused commits. The optional hint ($ARGUMENTS) provides guidance on what to commit, how to group changes, or what to emphasize in commit messages.

If the hint is unclear or ambiguous, **ASK THE USER** for clarification before proceeding.

Follow this iterative process:

## Review Phase

1. Check memory systems for commit strategies:
2. Run `git status` to see all modified files
3. Run `git diff` for each file to understand all changes
4. Run `git log --oneline -10` to see recent commit message patterns
5. Run `gh pr view` to see if a PR exists for these changes and review its title and body
6. **CRITICAL:** Review ALL changes thoroughly to understand the goals and context
7. **CRITICAL:** Consider the optional hint provided and how it should influence the commit strategy
8. **ASK THE USER** about any changes you can't understand the purpose of - don't guess
9. **ASK THE USER** for clarification if the hint is unclear or ambiguous
10. Identify any debug code, temporary changes, or unrelated modifications that shouldn't be committed

## Commit Strategy

1. **Apply the user's hint** to determine grouping strategy, content focus, or message emphasis
2. Group related changes into logical commits (e.g., separate documentation updates from code changes)
3. Create focused commits that each serve a single purpose
4. Prioritize commits in logical order (e.g., infrastructure before features)
5. Use angular-style commit messages (feat:, fix:, docs:, refactor:, etc.)
6. Focus commit messages on "why" not just "what"
7. Include context about the change's purpose and impact

## Execution

1. For each logical group of changes:
   - Add only specific files with `git add <specific-files>`
   - Create commit with detailed angular-style message
   - Verify the commit with `git show --stat`
2. **NEVER** use `git add .` - always be explicit about files
3. **EXCLUDE** debug code, temporary files, and unrelated changes
4. **ASK** the user if they want to push changes after all commits are complete. The hint may suggest pushing, in which case you do not need to ask the user.
5. If a PR exists for these changes, assume the PR title and/or body should be updated to reflect the new changes. Review the current state, and the changes just

## Example Workflows

**Default behavior:**

- Commit 1: `docs: update memory management guidelines to clarify MCP usage`
- Commit 2: `feat: add intelligent commit slash command for better git workflow`
- Commit 3: `fix: correct memory.json file format documentation`

**With hint `/scm-utils:commit each file separate`:**

- Commit 1: `docs: update commit.md to support optional hints`
- Commit 2: `docs: clarify memory management MCP tool differences`
- Commit 3: `feat: add new agent configuration file`

**With hint `/scm-utils:commit only documentation`:**

- Commit 1: `docs: update commit workflow and memory management guidelines`
- (Skip non-documentation changes)
