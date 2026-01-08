---
name: slash-command-writing
description: >
  Use this skill when creating, updating, or maintaining Claude Code slash commands.
  Activates when user asks to create a new command, modify an existing command,
  or asks questions about slash command syntax and best practices.
---

# Slash Command Writing Skill

This skill provides comprehensive guidance for creating and maintaining Claude Code slash commands.

## When to Activate This Skill

**Activate when:**

- User asks to "create a slash command" or "make a command"
- User wants to "add a new /command"
- User asks about slash command syntax or structure
- User wants to update or fix an existing command
- User asks how to use bash commands in slash commands
- User wants to add file references to a command

**Do NOT activate when:**

- User is just running an existing command
- User asks general questions about Claude Code (use claude-code-guide agent)
- User is creating skills (use skill-maintenance skill instead)

## Slash Command File Format

### Location

| Scope   | Location                       | Label in /help |
| ------- | ------------------------------ | -------------- |
| Project | `.claude/commands/<name>.md`   | (project)      |
| User    | `~/.claude/commands/<name>.md` | (user)         |

**Precedence:** Project commands override user commands with the same name.

### File Structure

```markdown
---
allowed-tools: Tool1, Tool2, Bash(command:*)
argument-hint: [arg1] [arg2]
description: Brief description shown in /help
model: claude-opus-4-5-20251101
disable-model-invocation: false
---

# Command Title

Your command instructions here.

Use $ARGUMENTS for all arguments or $1, $2, etc. for positional arguments.
```

### Frontmatter Fields

| Field                      | Required | Description                                          |
| -------------------------- | -------- | ---------------------------------------------------- |
| `description`              | Yes      | Brief text shown in `/help` output                   |
| `allowed-tools`            | No       | Tools the command can use (inherits if not set)      |
| `argument-hint`            | No       | Shows expected arguments in autocomplete             |
| `model`                    | No       | Specific model for this command                      |
| `disable-model-invocation` | No       | Prevent programmatic execution via SlashCommand tool |

## Argument Handling

### All Arguments

Use `$ARGUMENTS` to capture everything after the command name:

```markdown
---
description: Search codebase
argument-hint: [search query]
---

Search the codebase for: $ARGUMENTS
```

**Usage:** `/search function that handles auth` → `$ARGUMENTS` = `function that handles auth`

### Positional Arguments

Use `$1`, `$2`, `$3`, etc. for specific positions:

```markdown
---
description: Compare two files
argument-hint: [file1] [file2]
---

Compare the following files:

- First file: $1
- Second file: $2
```

**Usage:** `/compare src/old.js src/new.js` → `$1` = `src/old.js`, `$2` = `src/new.js`

## Bash Command Execution

Execute shell commands using the `!` backtick syntax. Output is included in the command context.

### Requirements

1. **MUST** include `allowed-tools` frontmatter with appropriate Bash permissions
2. Use the `` !`command` `` syntax (exclamation mark followed by backticks)

### Syntax

```markdown
---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*)
description: Show git context
---

## Current State

- Git status: !`git status`
- Recent commits: !`git log --oneline -5`
- Current branch: !`git branch --show-current`
```

### Bash Permission Patterns

| Pattern              | Allows                        |
| -------------------- | ----------------------------- |
| `Bash(git:*)`        | Any git command               |
| `Bash(git status:*)` | git status with any arguments |
| `Bash(npm:*)`        | Any npm command               |
| `Bash(ls:*)`         | ls with any arguments         |

### Common Bash Patterns

```markdown
## Git Context

---

## allowed-tools: Bash(git:\*)

- Status: !`git status --short`
- Branch: !`git branch --show-current`
- Diff (staged): !`git diff --staged`
- Recent commits: !`git log --oneline -10`
```

```markdown
## Package Info

---

## allowed-tools: Bash(npm:_), Bash(cat:_)

- Node version: !`node --version`
- Dependencies: !`npm ls --depth=0`
```

## File References

Include file contents using the `@` prefix:

```markdown
## Context Files

Review the implementation in @src/utils/helpers.js

Compare:

- Old: @src/old-version.js
- New: @src/new-version.js
```

**Behavior:**

- File paths can be relative or absolute
- `@` references automatically include `CLAUDE.md` files from the file's directory tree
- Directory references show file listings, not contents

## Extended Thinking

Trigger extended thinking by including thinking keywords:

```markdown
---
description: Complex architecture design
---

ultrathink: Design a comprehensive caching layer

Consider performance, memory usage, and invalidation strategies.
```

**Keywords:** `ultrathink`, `megathink`, `think hard`, etc.

## Best Practices

### DO

- Keep commands focused on a single purpose
- Use descriptive command names
- Include `description` frontmatter for discoverability
- Provide `argument-hint` when arguments are expected
- Test commands before committing
- Include examples in complex commands
- Use `allowed-tools` when using Bash commands

### DON'T

- Create overly complex commands (use Skills instead)
- Duplicate bash logic across commands
- Leave commands without descriptions
- Mix unrelated functionality in one command
- Use commands for things that need multi-step workflows

### Complexity Guideline

| Complexity Level     | Use                        |
| -------------------- | -------------------------- |
| Quick prompts        | Slash command              |
| Simple templates     | Slash command              |
| Multi-step workflows | Skill                      |
| Complex capabilities | Skill + supporting scripts |

## Namespacing

Organize related commands in subdirectories:

```
.claude/commands/
├── optimize.md              → /optimize (project)
├── frontend/
│   └── component.md         → /component (project:frontend)
└── backend/
    └── test.md              → /test (project:backend)
```

Subdirectories appear in `/help` descriptions but don't affect the command name.

## Creating a Command: Step-by-Step

### Step 1: Determine Scope

- **User command** (`~/.claude/commands/`): Personal, available everywhere
- **Project command** (`.claude/commands/`): Team-shared, repository-specific

### Step 2: Check for Existing Commands

```bash
# User commands
ls -la ~/.claude/commands/

# Project commands (from git root)
ls -la .claude/commands/
```

### Step 3: Create the File

```bash
# User command
mkdir -p ~/.claude/commands
touch ~/.claude/commands/my-command.md

# Project command
mkdir -p .claude/commands
touch .claude/commands/my-command.md
```

### Step 4: Write the Command

1. Add frontmatter with at least `description`
2. Add `allowed-tools` if using Bash
3. Write clear, specific instructions
4. Use `$ARGUMENTS` or `$1`, `$2` for parameters
5. Add bash commands with `` !`command` `` if needed
6. Include file references with `@path` if needed

### Step 5: Test the Command

1. Save the file
2. Run the command: `/my-command test arguments`
3. Verify behavior matches expectations
4. Iterate on instructions if needed

## Example Commands

### Simple Prompt Command

```markdown
---
description: Generate unit tests for a function
argument-hint: [function name or file path]
---

Generate comprehensive unit tests for: $ARGUMENTS

Include:

- Happy path tests
- Edge cases
- Error handling
- Mock dependencies where appropriate
```

### Context-Aware Command

```markdown
---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*)
argument-hint: [commit message prefix]
description: Smart commit with context
---

# Smart Commit

## Current State

- Status: !`git status`
- Changes: !`git diff HEAD`
- Recent style: !`git log --oneline -5`

## Task

Create a commit with the following requirements:

- Prefix: $ARGUMENTS (if provided)
- Follow conventional commit format
- Match existing commit style
```

### Multi-File Review Command

```markdown
---
description: Review PR changes comprehensively
argument-hint: [focus area]
allowed-tools: Bash(git:*)
---

# Code Review

## Changed Files

!`git diff --name-only HEAD~1`

## Full Diff

!`git diff HEAD~1`

## Review Focus

$ARGUMENTS

## Instructions

Provide feedback on:

1. Code quality and style
2. Potential bugs or issues
3. Performance considerations
4. Security implications
```

## Troubleshooting

### Command Not Found

1. Check file extension is `.md`
2. Verify file is in correct location
3. Check filename matches expected command name
4. Ensure frontmatter YAML is valid

### Bash Commands Not Running

1. Add `allowed-tools` frontmatter with Bash permissions
2. Use correct syntax: `` !`command` `` (not just backticks)
3. Check command is allowed by permission pattern

### Arguments Not Working

1. Use `$ARGUMENTS` for all args, `$1`, `$2` for positional
2. Make sure there's no space between `$` and number
3. Arguments are captured after the command name

### Command Activates Unexpectedly

1. Check `disable-model-invocation: true` to prevent programmatic execution
2. Review description for overly broad language

## Related Resources

- **Official Docs:** https://code.claude.com/docs/en/slash-commands.md
- **Common Workflows:** https://code.claude.com/docs/en/common-workflows.md
- **Skills vs Commands:** https://code.claude.com/docs/en/slash-commands.md#skills-vs-slash-commands
