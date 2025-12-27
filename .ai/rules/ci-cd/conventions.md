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
3. Work locally via justfile commands

## Prefer Marketplace Actions Over Custom Scripts

**CRITICAL:** When working with GitHub Actions workflows:

1. **Prefer popular upstream actions** over writing custom bash scripts
2. **Check what's already in use** in the repo before introducing new dependencies
3. **Be consistent** - if refactoring to use a different action, update all similar usages
4. Keep inline bash to a minimum (simple one-liners only)

Common actions already in use:

- `stefanzweifel/git-auto-commit-action@v5` - git config, add, commit, push
- `peter-evans/create-or-update-comment@v4` - PR comments
- `peter-evans/find-comment@v3` - finding existing comments

## Secrets Used

- `GITHUB_PAT_TOKEN_NSHEAPS`: For authenticated pushes
- `CLAUDE_CODE_OAUTH_TOKEN`: For Claude Code review

## See Also

- [Plugin Development](../plugin-development.md) - Plugin structure requirements
- [Versioning Rules](../versioning.md) - When version bumps are required
