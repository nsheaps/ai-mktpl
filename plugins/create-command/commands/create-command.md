---
name: create-command
description: Create a new slash command for user, current project, or specified location
argument-hint: "[SCOPE] <command-name> [description]"
allowed-tools: Read, Glob, Grep, Edit, Write, Bash(ls:*), Bash(mkdir:*), Bash(pwd:*), Bash(git rev-parse:*), AskUserQuestion, Task
---

# Create Slash Command

This command creates new slash commands. It uses a sub-agent to preserve conversation context while gathering requirements and writing the command.

## Skill Reference

For detailed syntax and best practices, see:
@~/src/nsheaps/ai-mktpl/plugins/create-command/skills/slash-command-writing/SKILL.md

## Arguments

**Format:** `[SCOPE] <command-name> [description]`

| Argument     | Required | Description                                     |
| ------------ | -------- | ----------------------------------------------- |
| SCOPE        | No       | `user`, `project`, or path to target project    |
| command-name | Yes      | Name of the command (without leading `/`)       |
| description  | No       | Brief description of what the command should do |

**Examples:**

- `/create-command user backup-db` - Create user command `backup-db`
- `/create-command project lint-fix` - Create project command `lint-fix`
- `/create-command ~/src/myproj deploy` - Create command in specific project
- `/create-command review-pr Review pull requests` - Infer scope, include description

## Process

Execute the following steps using a sub-agent (Task tool with `general-purpose` type):

### Step 1: Parse Arguments

Parse `$ARGUMENTS` to extract:

1. **Scope** (if first word matches):
   - `user` → `~/.claude/commands/`
   - `project` → `.claude/commands/` in current git root
   - `/path/to/project` → `.claude/commands/` in specified path

2. **Command name**: The identifier (e.g., `review-pr` creates `/review-pr`)

3. **Description**: Any remaining text after scope and name

**If scope is not specified:** Ask the user using AskUserQuestion with options:

- User (available everywhere)
- Current Project (shared with team)
- Specific Project (specify path)

### Step 2: Check for Existing Command

Check if the command already exists in the target location:

```
User commands:     ~/.claude/commands/<name>.md
Project commands:  <git-root>/.claude/commands/<name>.md
```

**If the command exists:**

1. Read the existing command file
2. Ask the user: "A command named `/<name>` already exists. Would you like to:"
   - Update/replace it
   - View it first, then decide
   - Cancel and keep existing

### Step 3: Gather Requirements

If description was not provided or is insufficient, ask the user:

1. **What should the command do?** - Get the core purpose
2. **What arguments does it need?** - Determine `$ARGUMENTS` vs `$1`, `$2` usage
3. **Does it need context from the environment?** - Git status, file contents, etc.
4. **Any special tools required?** - For `allowed-tools` frontmatter

### Step 4: Write the Command

Create the command file following the skill reference patterns:

**Required elements:**

1. Frontmatter with at least `description`
2. If using bash: `allowed-tools` with appropriate patterns
3. Clear instructions for Claude
4. Argument usage (`$ARGUMENTS` or positional)

**Standard structure:**

```markdown
---
description: <user's description or generated>
argument-hint: [inferred from requirements]
allowed-tools: <if bash commands needed>
---

# <Command Name>

<Clear instructions for what the command does>

## Context (if bash commands)

- <bash outputs using !`command` syntax>

## Task

<What Claude should do when this command runs>

## Arguments

$ARGUMENTS - <what they represent>
```

### Step 5: Confirm and Create

1. Show the user the proposed command file
2. Ask for confirmation before creating
3. Create the directory if it doesn't exist
4. Write the command file
5. Suggest testing with an example invocation

## Scope Resolution Logic

```
If first argument matches scope keyword:
  user      → ~/.claude/commands/
  project   → <current-git-root>/.claude/commands/
  ~/path/*  → <expanded-path>/.claude/commands/
  /abs/path → <path>/.claude/commands/

Else if working in a git repository:
  Ask: "Create for user (global) or this project?"

Else:
  Default to user: ~/.claude/commands/
```

## File Location Summary

| Scope          | Directory                      | Precedence |
| -------------- | ------------------------------ | ---------- |
| User           | `~/.claude/commands/`          | Lower      |
| Project        | `<git-root>/.claude/commands/` | Higher     |
| Specified Path | `<path>/.claude/commands/`     | Depends    |

**Note:** Project commands override user commands with the same name.

## Bash Syntax Reference

When the command needs to execute shell commands:

1. **Add to frontmatter:**

   ```yaml
   allowed-tools: Bash(git status:*), Bash(ls:*)
   ```

2. **Use in command body:**
   ```markdown
   Current status: !`git status`
   ```

**Pattern format:** `Bash(<command>:<args-pattern>)`

- `Bash(git:*)` - any git command
- `Bash(git status:*)` - git status with any args
- `Bash(npm run:*)` - npm run with any args

## Common Command Patterns

### Status/Context Command

```markdown
---
allowed-tools: Bash(git:*), Bash(npm:*)
description: Show development context
---

## Environment

- Branch: !`git branch --show-current`
- Status: !`git status --short`
- Node: !`node --version`
```

### Action Command

```markdown
---
description: Format and lint code
allowed-tools: Bash(npm:*), Bash(git:*)
argument-hint: [files or --all]
---

Run formatting and linting on: $ARGUMENTS

Steps:

1. Run prettier
2. Run eslint with --fix
3. Stage any auto-fixed changes
```

### Analysis Command

```markdown
---
description: Analyze code for issues
argument-hint: [file or pattern]
---

Analyze the following for potential issues: $ARGUMENTS

Check for:

- Security vulnerabilities
- Performance problems
- Code smells
- Missing error handling
```

## Examples

### Example 1: Simple User Command

```
/create-command user standup
```

Creates: `~/.claude/commands/standup.md`

Might generate:

```markdown
---
description: Generate daily standup summary
allowed-tools: Bash(git log:*)
---

# Daily Standup

## Recent Activity

!`git log --oneline --since="yesterday" --author="$(git config user.email)"`

## Task

Summarize my recent work for a standup meeting.
```

### Example 2: Project Command with Arguments

```
/create-command project test-component Run tests for a specific component
```

Creates: `<git-root>/.claude/commands/test-component.md`

Might generate:

```markdown
---
description: Run tests for a specific component
argument-hint: [component-name]
allowed-tools: Bash(npm test:*), Bash(jest:*)
---

# Component Test Runner

Run tests for component: $ARGUMENTS

## Task

1. Find test files matching the component name
2. Run the tests
3. Report results with any failures highlighted
```

### Example 3: Specific Project

```
/create-command ~/src/backend deploy-staging Deploy to staging environment
```

Creates: `~/src/backend/.claude/commands/deploy-staging.md`

## Important Notes

- **Test after creation:** Remind user to test with `/command-name test-args`
- **Iterative refinement:** Commands can be updated using this same command
- **Don't over-engineer:** Start simple, add complexity only when needed
- **Reference the skill:** Complex scenarios should consult the full SKILL.md
- **Use claude-code-guide agent:** You can and should consider using the `claude-code-guide` agent to help you with any changes needed to Claude Code configuration files.
- **Work on main branch:** When creating commands, make the change directly on the main branch and `/commit` and push after completing the creation.
