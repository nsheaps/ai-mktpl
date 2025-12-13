# Commit Command Plugin

Automate git commits with AI-generated messages that match your repository's commit style and conventions.

## Overview

The Commit Command plugin provides a `/commit` slash command that intelligently analyzes your code changes and creates commits with well-formatted messages that follow your repository's established conventions.

## Features

✅ **Intelligent Message Generation**: Analyzes changes to create descriptive, semantic commit messages
✅ **Style Learning**: Studies your commit history to match your repository's conventions
✅ **Conventional Commits**: Supports `feat:`, `fix:`, `docs:`, `refactor:`, and other conventional formats
✅ **Security-Aware**: Automatically excludes sensitive files (.env, credentials.json, etc.)
✅ **Smart Staging**: Stages relevant files while respecting .gitignore
✅ **Issue References**: Detects and includes issue/ticket numbers
✅ **Custom Prefixes**: Supports custom message prefixes and formats

## Installation

### Via Claude Code Plugin Manager

1. Open Claude Code
2. Run `/plugin marketplace add nsheaps/.ai`
3. Find "Commit Command" plugin
4. Click "Install now"
5. Restart Claude Code

### Manual Installation

```bash
# Navigate to plugins directory
cd ~/.claude/plugins

# Copy the plugin
cp -r /path/to/marketplace/plugins/commit-command ~/.claude/plugins/

# Restart Claude Code
```

## Usage

### Basic Usage

```bash
/commit
```

Analyzes all staged and unstaged changes, generates a commit message, and creates the commit.

### With Message Prefix

```bash
/commit feat:
/commit fix:
/commit docs:
/commit refactor:
```

Guides the message generation to start with specific prefixes.

### With Custom Message Hint

```bash
/commit [TASK-123] add new feature
```

Uses your hint to guide message generation.

## Examples

### Example 1: Automatic Feature Commit

```bash
# After implementing user authentication
/commit

# Result: "feat: add JWT-based user authentication system"
```

### Example 2: Bug Fix with Conventional Commits

```bash
# After fixing a bug
/commit fix:

# Result: "fix: resolve null pointer in payment processor"
```

### Example 3: Issue Reference

```bash
# After fixing issue #456
/commit fix: resolve #456

# Result: "fix: handle special characters in login (#456)"
```

### Example 4: Documentation Update

```bash
# After updating docs
/commit docs:

# Result: "docs: update installation instructions and add troubleshooting"
```

## How It Works

1. **Analyzes Changes**: Runs `git status` and `git diff` to understand modifications
2. **Studies History**: Examines recent commits with `git log` to learn your style
3. **Detects Type**: Identifies if changes are features, fixes, refactoring, etc.
4. **Generates Message**: Creates a semantic message matching your conventions
5. **Stages Files**: Runs `git add` for relevant files
6. **Creates Commit**: Executes `git commit` with the generated message

## Configuration

The plugin works out of the box with sensible defaults, but adapts to your preferences:

### Commit Message Conventions

The plugin detects and adapts to:
- **Conventional Commits**: `type(scope): description`
- **Issue References**: `#123`, `[JIRA-456]`, `Fixes #789`
- **Custom Formats**: Learns from your existing commits
- **Capitalization**: Matches your style (lowercase, uppercase, title case)
- **Tense**: Adapts to imperative or past tense

### Sensitive File Exclusion

Automatically excludes:
- `.env*` files
- `credentials.json`
- `secrets.yml`
- `*.pem`, `*.key` files
- API key files
- SSH keys
- Database credentials

## Best Practices

### Before Committing

1. **Review your changes**: Run `git diff` to see what you modified
2. **Stage intentionally**: Use `git add` for specific files if needed
3. **Unstage unwanted files**: Use `git reset` to unstage files

### Using the Command

1. **Atomic commits**: Keep each commit focused on one logical change
2. **Use prefixes**: Guide message generation with `feat:`, `fix:`, etc.
3. **Provide context**: Add hints when changes might be ambiguous
4. **Review before pushing**: Check the commit with `git log -1`

### Workflow Integration

```bash
# 1. Make your changes
vim src/auth.js

# 2. Review changes
git diff

# 3. Create commit
/commit feat:

# 4. Verify commit
git log -1

# 5. Push to remote
git push
```

## Troubleshooting

### Command Not Found

**Problem**: `/commit` command doesn't work

**Solutions**:
- Verify plugin is in `~/.claude/plugins/commit-command/`
- Restart Claude Code
- Check plugin is enabled in settings

### No Changes to Commit

**Problem**: "No changes to commit" message

**Solutions**:
- Run `git status` to verify you have modifications
- Ensure files aren't in .gitignore
- Check you're in a git repository

### Message Doesn't Match Style

**Problem**: Generated messages don't follow your conventions

**Solutions**:
- Make a few manual commits to establish patterns
- Use argument hints to guide generation
- Specify your convention explicitly: "Use Conventional Commits format"

### Sensitive Files Warning

**Problem**: Warning about sensitive files

**Solutions**:
- Add files to `.gitignore`
- Review and verify files are safe to commit
- Use `git add` to explicitly stage specific files

## Advanced Usage

### With Pre-commit Hooks

The command works seamlessly with pre-commit hooks:

```bash
# If hooks modify files, the command will handle it
/commit

# Hooks run automatically
# Files are reformatted by hooks
# Commit is created or retried if needed
```

### Custom Message Formats

Guide the command to your specific needs:

```bash
# Emoji prefixes
/commit ✨ add feature

# Ticket references
/commit [PROJ-123] implement feature

# Custom format
/commit WIP: partial implementation
```

### Multi-file Staging

```bash
# Stage specific files first
git add src/auth.js src/login.js

# Commit only staged files
/commit feat: add authentication

# Stage and commit remaining changes separately
git add test/auth.test.js
/commit test: add auth tests
```

## Requirements

- **Claude Code**: Latest version
- **Git**: Installed and configured (`git config user.name` and `git config user.email`)
- **Repository**: Must be in a git repository
- **History**: At least one existing commit (for style learning)

## Allowed Tools

The command uses these tools:
- `Bash(git add:*)` - Stage files
- `Bash(git status:*)` - Check repository status
- `Bash(git commit:*)` - Create commits
- `Bash(git diff:*)` - Analyze changes
- `Bash(git log:*)` - Study commit history
- `Read` - Read file contents if needed
- `Glob` - Find files by pattern

## Security

### What's Protected

- Environment variables files
- Credential files
- Private keys and certificates
- API keys and tokens
- Database connection strings

### What's Committed

The command only commits:
- Source code files
- Configuration files (non-sensitive)
- Documentation
- Tests
- Public assets

## Performance

- **Fast**: Typically completes in 2-5 seconds
- **Efficient**: Only analyzes changed files
- **Smart**: Caches commit history patterns

## Limitations

- Cannot commit to protected branches without permissions
- Requires at least one existing commit for style detection
- Won't commit during merge conflicts or rebases
- Respects pre-commit hook failures

## Related Plugins

- **[Smart Commit Skill](../commit-skill)**: Automatic skill version for during-development commits

## Support

- **Issues**: [GitHub Issues](https://github.com/nsheaps/.ai/issues)
- **Documentation**: [Main README](../../README.md)
- **Claude Code Docs**: [https://code.claude.com/docs](https://code.claude.com/docs)

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - see [LICENSE](../../LICENSE)

## Changelog

### Version 1.0.0
- Initial release
- Intelligent commit message generation
- Conventional Commits support
- Security-aware file handling
- Repository style learning

---

**Made with Claude Code** | Part of the [Claude Code Plugin Marketplace](../../README.md)
