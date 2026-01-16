# Smart Commit Skill Plugin

Intelligent skill that enables Claude to automatically analyze git changes and create well-formatted commits during development tasks.

## Overview

The Smart Commit Skill is an agent skill that allows Claude to intelligently handle git commits while you're developing. Unlike the slash command version, this skill activates automatically when appropriate, creating atomic commits with semantic messages that match your repository's conventions.

## Features

✅ **Auto-Activation**: Claude automatically uses this skill during development tasks
✅ **Semantic Analysis**: Understands the nature of your changes (feat, fix, refactor, etc.)
✅ **Convention Detection**: Learns and follows your repository's commit message patterns
✅ **Atomic Commits**: Creates focused, single-purpose commits
✅ **Smart Grouping**: Organizes related changes into logical commits
✅ **Security-Aware**: Never commits sensitive files
✅ **Style Adaptation**: Matches your commit message style and conventions

## Installation

See [Installation Guide](../../docs/installation.md) for all installation methods.

### Quick Install

```bash
# Via marketplace (recommended)
# Follow marketplace setup: ../../docs/manual-installation.md

# Or via GitHub
claude plugins install github:nsheaps/.ai/plugins/commit-skill

# Or locally for testing
cc --plugin-dir /path/to/plugins/commit-skill
```

## How It Works

The skill operates transparently during your development workflow:

### Automatic Activation

Claude activates this skill when:

- Completing development tasks
- Multiple files have been modified
- Working in repositories with commit conventions
- Preparing changes for code review
- Organizing work into commits

### What Claude Does

1. **Analyzes Changes**: Examines modified files semantically
2. **Detects Conventions**: Studies your commit history
3. **Groups Logically**: Organizes changes into atomic commits
4. **Generates Messages**: Creates semantic commit messages
5. **Stages Files**: Stages related files together
6. **Creates Commits**: Makes one or more focused commits

## Usage Examples

### Example 1: Feature Implementation

```
You: "Add user authentication with JWT tokens"

Claude:
- Implements authentication across multiple files
- Recognizes this is a new feature
- Creates commit: "feat: add JWT-based user authentication"
```

### Example 2: Bug Fix

```
You: "Fix the null pointer error in payment processing"

Claude:
- Investigates and fixes the bug
- Identifies this as a bug fix
- Creates commit: "fix: prevent null pointer in payment processor"
```

### Example 3: Multi-Part Refactoring

```
You: "Refactor the database layer to use repositories"

Claude:
- Refactors multiple files
- Creates atomic commits:
  * "refactor: extract user repository"
  * "refactor: extract product repository"
  * "refactor: update connection logic"
```

### Example 4: Mixed Changes

```
You: "Add profile page with tests and documentation"

Claude creates separate commits:
- "feat: create user profile page component"
- "test: add profile page unit tests"
- "docs: update README with profile page info"
```

## Capabilities

### Change Type Detection

The skill identifies changes as:

- **feat**: New features or functionality
- **fix**: Bug fixes and corrections
- **refactor**: Code restructuring
- **docs**: Documentation updates
- **test**: Test additions/updates
- **chore**: Maintenance tasks
- **perf**: Performance improvements
- **style**: Formatting changes
- **ci**: CI/CD changes
- **build**: Build system updates

### Atomic Commit Strategy

Creates commits that are:

- Focused on one logical change
- Independently reviewable
- Bisect-friendly
- Easy to revert if needed
- Well-documented with clear messages

### Repository Adaptation

Learns from your repository:

- Commit message format
- Imperative vs. past tense
- Capitalization style
- Line length preferences
- Scope formatting
- Issue reference patterns

## Configuration

The skill adapts automatically, but you can guide it:

### Setting Conventions

```
"Use Conventional Commits format"
"Include ticket numbers from branch names"
"Keep messages under 50 characters"
"Use emoji prefixes for commit types"
"Separate features from tests in different commits"
```

### Custom Patterns

```
"Always reference Jira tickets: [PROJ-123]"
"Use past tense: 'Added feature' not 'Add feature'"
"Include scope: 'feat(api): add endpoint'"
```

## Best Practices

### Let Claude Commit Naturally

```
You: "Implement the shopping cart feature"

Claude:
- Implements the feature
- Automatically creates appropriate commit(s)
- You focus on reviewing, not commit management
```

### Provide Context When Needed

```
You: "Fix the bug and make sure to reference issue #456"

Claude:
- Fixes the bug
- Creates commit: "fix: resolve login issue (#456)"
```

### Trust the Atomic Commits

```
You: "Add search functionality with filters and pagination"

Claude creates logical commits:
- "feat: add basic search functionality"
- "feat: implement search filters"
- "feat: add pagination to search results"
- "test: add search feature tests"
```

## Security Features

### Never Commits Sensitive Files

Protected file types:

- `.env*` - Environment variables
- `credentials.json` - Credential files
- `secrets.yml` - Secret configuration
- `*.pem`, `*.key` - Private keys
- API keys and tokens
- Database passwords
- SSH keys
- Certificates

### Safe Commit Practices

- Validates changes before committing
- Respects .gitignore patterns
- Checks for sensitive content
- Warns about potential security issues

## Advanced Features

### Pre-commit Hook Integration

Works seamlessly with hooks:

- Respects hook requirements
- Handles auto-formatting
- Retries if hooks modify files
- Reports hook failures

### Multi-Commit Organization

For complex changes:

```
You: "Migrate authentication from sessions to JWT"

Claude organizes into commits:
1. "refactor: extract auth logic into service"
2. "feat: implement JWT token generation"
3. "feat: add JWT verification middleware"
4. "refactor: update login to use JWT"
5. "test: add JWT authentication tests"
6. "docs: update auth documentation"
```

### Branch-Aware Committing

```
# On feature branch
Claude commits: "feat: add new feature"

# On fix branch
Claude commits: "fix: resolve issue"

# Learns from branch naming patterns
```

## Workflow Integration

### With Pull Requests

```
You: "Prepare this work for PR"

Claude:
- Reviews all changes
- Creates logical commits
- Ensures descriptive messages
- Verifies nothing uncommitted
```

### With Code Review

```
Reviewer: "These commits need better organization"

You: "Claude, reorganize these commits"

Claude:
- Analyzes existing commits
- Suggests better organization
- Can create new commits or amend existing ones
```

### With CI/CD

```
# Commits trigger CI
Claude ensures:
- Each commit is complete
- Tests pass at each commit
- No broken intermediate states
```

## Troubleshooting

### Skill Not Activating

**Problem**: Skill doesn't seem to be working

**Solutions**:

- Verify installation in `~/.claude/skills/commit-skill/`
- Ensure you're in a git repository
- Check there are changes to commit
- Restart Claude Code

### Messages Don't Match Style

**Problem**: Commit messages don't follow your conventions

**Solutions**:

- Make manual commits to establish patterns
- Explicitly state your conventions
- The skill learns over time

### Too Many/Few Commits

**Problem**: Commits aren't organized as expected

**Solutions**:

- Provide guidance on commit granularity
- Specify "create one commit" or "create atomic commits"
- The skill learns your preferences

### Files Not Staged

**Problem**: Expected files aren't committed

**Solutions**:

- Check `.gitignore` patterns
- Verify file permissions
- Ensure files aren't marked as sensitive

## Comparison with Commit Command

| Feature      | Smart Commit Skill               | Commit Command               |
| ------------ | -------------------------------- | ---------------------------- |
| Activation   | Automatic during development     | Manual with `/commit`        |
| Use Case     | Ongoing development workflow     | Explicit commit creation     |
| Multi-commit | Creates multiple logical commits | Single commit per invocation |
| Learning     | Learns during session            | Analyzes history per run     |
| User Control | Transparent, can guide           | Explicit control             |

### When to Use Each

**Use the Skill when:**

- Actively developing features
- Want Claude to handle commits automatically
- Working on multi-part implementations
- Prefer transparent commit management

**Use the Command when:**

- Want explicit control over commits
- Need to commit specific changes
- Prefer manual commit workflow
- Want to review before committing

## Requirements

- **Claude Code**: Latest version with skills support
- **Git**: Installed and configured
- **Repository**: Must be a git repository
- **Permissions**: Write access to repository

## Allowed Tools

The skill uses:

- `Bash(git add:*)` - Stage files
- `Bash(git status:*)` - Check status
- `Bash(git commit:*)` - Create commits
- `Bash(git diff:*)` - Analyze changes
- `Bash(git log:*)` - Study history
- `Read` - Read file contents
- `Glob` - Find files

## Performance

- **Transparent**: No noticeable slowdown
- **Efficient**: Only activates when needed
- **Smart**: Caches patterns and preferences

## Limitations

- Requires git repository
- Needs existing commits for style learning
- Won't commit during merge conflicts
- Respects pre-commit hook failures
- Cannot push to protected branches

## Related Plugins

- **[Commit Command](../commit-command)**: Manual slash command version

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

## Changelog

### Latest

- Improved version bump commit messages with plugin-specific formatting
- Added automatic prettier formatting after version bumps
- Enhanced CI integration by removing skip-ci tags

### Version 1.0.0

- Initial release
- Automatic skill activation
- Semantic change analysis
- Convention detection
- Atomic commit strategy
- Security-aware handling
- Repository style learning

---

**Made with Claude Code** | Part of the [Claude Code Plugin Marketplace](../../README.md)
