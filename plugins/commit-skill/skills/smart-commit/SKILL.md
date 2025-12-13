---
name: smart-commit-analyzer
description: Automatically analyze git changes and create well-formatted commits matching repository conventions during development tasks
---

# Smart Commit Analyzer Skill

This skill enables Claude to intelligently handle git commits during development sessions, automatically creating atomic commits with semantic messages that match your repository's established conventions.

## When Claude Activates This Skill

Claude will automatically use this skill when:

- **Completing Development Tasks**: After implementing features, fixing bugs, or making code changes
- **Multiple File Changes**: When multiple related files have been modified and need organized commits
- **Following Conventions**: Working in repositories with established commit message patterns (Conventional Commits, semantic versioning, etc.)
- **Code Review Ready**: Preparing changes to be committed before creating pull requests
- **Iterative Development**: During multi-step feature implementation requiring logical commit boundaries

## What This Skill Enables

### 1. Intelligent Change Analysis
- Examines staged and unstaged changes semantically
- Identifies the type of change (feature, fix, refactor, docs, test, etc.)
- Groups related changes logically
- Detects breaking changes and significant modifications

### 2. Convention Detection
- Learns from existing commit history
- Identifies commit message patterns:
  - Conventional Commits (`feat:`, `fix:`, `docs:`, etc.)
  - Issue references (`#123`, `[JIRA-456]`, `Fixes #789`)
  - Custom organizational formats
  - Emoji prefixes and tags
- Maintains consistency across commits

### 3. Smart File Staging
- Stages related files together for atomic commits
- Groups changes by logical functionality
- Respects `.gitignore` patterns
- Excludes sensitive files automatically

### 4. Security-Aware Committing
Claude will **never** commit files that may contain sensitive information:
- Environment files (`.env*`)
- Credential files (`credentials.json`, `secrets.yml`, `*.pem`, `*.key`)
- API keys and tokens
- Private certificates
- Database passwords
- SSH keys

### 5. Semantic Message Generation
Creates commit messages that:
- Accurately describe the changes and their purpose
- Match your repository's established style
- Include appropriate scope and context
- Reference related issues or tickets
- Follow conventional commit formats when detected

## How Claude Uses This Skill

### Scenario 1: Feature Implementation
```
User: "Add user authentication with JWT tokens"

Claude's workflow with this skill:
1. Implements authentication code across multiple files
2. Recognizes this is a new feature addition
3. Analyzes recent commits to detect "feat:" prefix usage
4. Stages all authentication-related files together
5. Creates commit: "feat: add JWT-based user authentication"
6. May create separate commits for tests vs implementation
```

### Scenario 2: Bug Fix
```
User: "Fix the null pointer error in payment processing"

Claude's workflow:
1. Investigates and fixes the bug
2. Identifies this as a bug fix
3. Detects "fix:" convention in commit history
4. Stages modified payment files
5. Creates commit: "fix: prevent null pointer in payment processor"
6. References issue number if mentioned
```

### Scenario 3: Multi-Part Refactoring
```
User: "Refactor the database layer to use repositories"

Claude's workflow:
1. Refactors multiple database files
2. Recognizes this is a refactoring task
3. Creates multiple atomic commits:
   - "refactor: extract user repository"
   - "refactor: extract product repository"
   - "refactor: update database connection logic"
4. Each commit is focused and reviewable
```

## Skill Capabilities

### Change Type Detection
Claude can identify and categorize changes as:

- **feat**: New features or functionality
- **fix**: Bug fixes and error corrections
- **refactor**: Code restructuring without behavior changes
- **docs**: Documentation updates
- **test**: Adding or updating tests
- **chore**: Maintenance tasks, dependency updates
- **perf**: Performance improvements
- **style**: Code style/formatting changes
- **ci**: CI/CD configuration changes
- **build**: Build system or external dependency changes

### Atomic Commit Strategy
The skill helps Claude create focused commits:

- One logical change per commit
- Separates features from fixes
- Splits large changes into reviewable chunks
- Maintains clean commit history
- Facilitates easier code review
- Enables better git bisect usage

### Repository Style Adaptation
Claude learns your preferences:

- Analyzes last 10-20 commits for patterns
- Detects imperative vs. past tense
- Identifies capitalization conventions
- Recognizes line length limits
- Adapts to scope formatting
- Learns issue reference formats

## Usage Examples

### Example 1: Automatic Commit During Feature Work
```
User: "Implement dark mode toggle in the settings page"

Claude:
1. Creates toggle component
2. Adds dark mode CSS variables
3. Implements theme switching logic
4. Automatically commits: "feat: add dark mode toggle to settings"
```

### Example 2: Multiple Related Commits
```
User: "Add user profile page with avatar upload"

Claude creates atomic commits:
1. "feat: create user profile page component"
2. "feat: add avatar upload functionality"
3. "test: add tests for profile page"
4. "docs: update README with profile page info"
```

### Example 3: Bug Fix with Context
```
User: "Fix issue #456 - login fails with special characters"

Claude commits: "fix: handle special characters in login (#456)"
```

## Best Practices Followed

### Commit Message Structure
```
<type>[optional scope]: <description>

[optional body]

[optional footer]
```

### Examples of Well-Formed Messages
- `feat: add user authentication system`
- `fix: resolve memory leak in image processor`
- `refactor(api): simplify error handling logic`
- `docs: update installation instructions`
- `test: add unit tests for validation`

### What Claude Won't Do
- Commit commented-out code without purpose
- Create commits with generic messages like "update files"
- Combine unrelated changes in a single commit
- Commit without understanding the changes
- Skip verification of what's being committed
- Commit sensitive or credential files

## Configuration and Customization

### Repository-Specific Patterns
Claude adapts to your repository's patterns automatically, but you can guide it:

```
"Always use Conventional Commits format"
"Include ticket numbers from branch name in commits"
"Use emoji prefixes: ✨ for features, 🐛 for fixes"
"Keep commit messages under 50 characters"
```

### Pre-commit Hook Integration
This skill works seamlessly with pre-commit hooks:
- Respects hook requirements
- Handles auto-formatting from hooks
- Retries commits if hooks modify files
- Reports hook failures clearly

## Workflow Integration

### With Pull Requests
```
User: "Prepare this work for PR"

Claude:
1. Reviews all uncommitted changes
2. Creates logical, atomic commits
3. Ensures commit messages are descriptive
4. Verifies all changes are committed
5. Ready for PR creation
```

### With Code Review
```
Reviewer: "These changes need better commit organization"

Claude:
1. Can reorganize commits using interactive rebase
2. Splits large commits into smaller ones
3. Improves commit messages
4. Maintains chronological coherence
```

## Technical Details

### Git Commands Used
- `git status` - Identify changed files
- `git diff` - Analyze actual changes
- `git log` - Study commit history and patterns
- `git add` - Stage files for commit
- `git commit` - Create commits with generated messages

### Pattern Recognition
The skill uses AI to:
- Parse commit message structures
- Identify semantic change types
- Detect organizational conventions
- Match tone and style
- Preserve context and references

### Safety Mechanisms
- Pre-commit validation
- Sensitive file detection
- Staged changes verification
- Commit message review
- Hook compliance checking

## Requirements

- Git repository initialized
- At least one existing commit (for style learning)
- Git configured with user name and email
- Write access to the repository

## Limitations

- Cannot commit to protected branches without permissions
- Respects pre-commit hooks (may require hook fixes)
- Requires valid git configuration
- Cannot resolve merge conflicts automatically
- Won't commit during ongoing rebase or merge operations

## Troubleshooting

**Skill not activating**: Ensure you're in a git repository with changes to commit

**Messages don't match style**: The skill learns from history; make a few manual commits to establish patterns

**Files not staged**: Check `.gitignore` and file permissions

**Commit rejected**: Review pre-commit hook output; the skill will report errors clearly

## Learning and Improvement

The skill improves with usage:
- Learns repository-specific conventions over time
- Adapts to feedback on commit messages
- Recognizes project-specific patterns
- Understands domain terminology from existing commits

## Attribution

Commits created through this skill include Claude Code attribution in commit metadata, maintaining transparency about AI-assisted development.
