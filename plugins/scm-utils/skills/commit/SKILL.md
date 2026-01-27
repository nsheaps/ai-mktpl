---
name: commit
description: Intelligently commit outstanding changes in logical, focused commits
argument-hint: [optional hint]
---

# Intelligent Commit Process

You should commit outstanding changes by breaking them into logical, focused commits. The optional hint ($ARGUMENTS) provides guidance on what to commit, how to group changes, or what to emphasize in commit messages.

If the hint is unclear or ambiguous, **ASK THE USER** for clarification before proceeding.

Follow this iterative process:

## Review Phase

1. Check memory systems for commit strategies:
   - Use Serena's `read_memory commit_strategy` for project-specific patterns
   - Check Memory MCP for user preferences on commit structure
2. Run `git status` to see all modified files
3. Run `git diff` for each file to understand all changes
4. Run `git log --oneline -10` to see recent commit message patterns
5. **CRITICAL:** Review ALL changes thoroughly to understand the goals and context
6. **CRITICAL:** Consider the optional hint provided and how it should influence the commit strategy
7. **ASK THE USER** about any changes you can't understand the purpose of - don't guess
8. **ASK THE USER** for clarification if the hint is unclear or ambiguous
9. Identify any debug code, temporary changes, or unrelated modifications that shouldn't be committed

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
5. If a PR exists for these changes, **ASK** the user if it should be updated to reflect the new changes.

## Example Workflows

**Default behavior:**

- Commit 1: `docs: update memory management guidelines to clarify MCP usage`
- Commit 2: `feat: add intelligent commit slash command for better git workflow`
- Commit 3: `fix: correct memory.json file format documentation`

**With hint `/commit each file separate`:**

- Commit 1: `docs: update commit.md to support optional hints`
- Commit 2: `docs: clarify memory management MCP tool differences`
- Commit 3: `feat: add new agent configuration file`

**With hint `/commit only documentation`:**

- Commit 1: `docs: update commit workflow and memory management guidelines`
- (Skip non-documentation changes)
