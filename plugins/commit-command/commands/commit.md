---
name: commit
description: Analyze changes and create a git commit with an AI-generated message matching your repo's style
argument-hint: "[optional commit message prefix]"
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Read, Glob
---

# Smart Commit Command

Automatically analyze your git changes and create commits with intelligently generated messages that match your repository's commit conventions.

## What This Command Does

1. **Analyzes Current State**: Examines both staged and unstaged changes in your repository
2. **Studies Your Style**: Reviews recent commit history to understand your repository's commit message conventions
3. **Intelligent Staging**: Stages relevant files while excluding sensitive files (.env, credentials.json, etc.)
4. **Generates Message**: Creates a descriptive commit message following your project's style
5. **Creates Commit**: Commits the changes with the generated message

## Usage

```bash
/commit                          # Analyze all changes and create a commit
/commit fix:                     # Start message with "fix:"
/commit feat: add new feature    # Use custom message prefix
/commit docs                     # Start message with "docs"
```

## Arguments

**$ARGUMENTS** (optional): Provide a prefix or hint for the commit message generation. This helps guide the AI to create messages in your preferred format.

## Examples

### Basic Usage
```bash
/commit
```
Analyzes all changes and generates a commit message like:
- `feat: add user authentication with JWT tokens`
- `fix: resolve null pointer in payment processor`
- `refactor: simplify database connection logic`

### With Conventional Commits
```bash
/commit feat:
```
Ensures the message starts with "feat:" for feature additions.

```bash
/commit fix:
```
Ensures the message starts with "fix:" for bug fixes.

### Custom Prefixes
```bash
/commit [TASK-123]
```
Adds ticket reference to the commit message.

## Safety Features

- **Excludes Sensitive Files**: Never commits files containing secrets:
  - `.env`, `.env.local`, `.env.production`
  - `credentials.json`, `secrets.yml`
  - Private keys, certificates
  - API keys and tokens

- **Pre-commit Verification**: Shows you the generated commit message before committing

- **Smart Staging**: Only stages files relevant to the current changes

## Commit Message Style Detection

The command analyzes your recent commits to detect patterns:

- **Conventional Commits**: `feat:`, `fix:`, `docs:`, `refactor:`, etc.
- **Issue References**: `[JIRA-123]`, `#456`, `Fixes #789`
- **Custom Formats**: Learns from your existing commit history
- **Semantic Versioning**: Understands breaking changes and features

## How It Works

1. Runs `git status` to identify modified, staged, and untracked files
2. Runs `git diff` to analyze the actual changes in your code
3. Runs `git log` to study your recent commit message patterns
4. Analyzes the changes semantically (new features, bug fixes, refactoring, etc.)
5. Generates a commit message matching your repository's style
6. Stages appropriate files with `git add`
7. Creates the commit with `git commit -m`

## Best Practices

- **Atomic Commits**: Make commits focused on a single logical change
- **Review Changes**: Use `git diff` before running `/commit` to verify your changes
- **Unstage Unwanted Files**: Use `git reset` to unstage files you don't want to commit
- **Meaningful Context**: Add argument hints when the changes might be ambiguous

## Workflow Integration

This command works seamlessly with your development workflow:

```bash
# After making changes to your code
/commit

# For specific types of changes
/commit feat:     # Adding a feature
/commit fix:      # Fixing a bug
/commit docs:     # Documentation updates
/commit refactor: # Code refactoring
/commit test:     # Adding tests
/commit chore:    # Maintenance tasks
```

## Requirements

- Must be run in a git repository
- Git must be installed and configured
- Repository must have at least one existing commit (for style detection)

## Troubleshooting

**No changes to commit**: Ensure you have modified files. Run `git status` to check.

**Sensitive files detected**: The command will warn you if it detects files that might contain secrets. Review and either add them to `.gitignore` or explicitly stage them separately.

**Commit message doesn't match style**: Run the command again with an argument hint, or the command will learn from your manual commits over time.

## Attribution

Commits created with this command include attribution to Claude Code in the commit metadata.
