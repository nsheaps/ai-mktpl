# CI/CD Conventions

## Workflows

### ci.yaml (Continuous Integration)

- **Triggers**: PR to any branch, push to main, manual dispatch
- **Jobs**:
  - `lint`: Multi-language linting with auto-fix
  - `validate`: Plugin structure validation

### cd.yaml (Continuous Deployment)

- **Triggers**: Push to main or PR with `plugins/**` changes
- **Jobs**:
  - `check-version-bump`: Enforces semantic versioning in PRs
  - `update-marketplace`: Updates marketplace.json on main

### claude-code-review.yml

- **Triggers**: PR opened/synchronized
- **Purpose**: AI-powered code review using Claude Code

## Action Conventions

Every action in `.github/actions/` must:

1. Have a test workflow that runs when the action changes
2. Include a dry-run mode for PR validation
3. Scripts >3 lines should be in separate files for linting
4. Work locally via justfile commands

## Git Push Retry Logic

All workflows use exponential backoff (4 attempts: 2s, 4s, 8s, 16s).

## Secrets Used

- `GITHUB_PAT_TOKEN_NSHEAPS`: For authenticated pushes
- `CLAUDE_CODE_OAUTH_TOKEN`: For Claude Code review
