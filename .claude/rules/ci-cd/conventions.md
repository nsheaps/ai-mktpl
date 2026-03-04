# CI/CD Conventions

## Workflows

### ci.yaml (Continuous Integration)

- **Triggers**: PR to any branch, push to main, manual dispatch
- **Jobs**:
  - `check-version-files`: Blocks manual modifications to existing plugin.json and marketplace.json (new plugin.json files are allowed)
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

## Prefer Justfile Over Custom Actions

**CRITICAL:** Business logic should live in justfile recipes, not composite actions.

- Composite actions should be thin wrappers that call `just <recipe>`
- This ensures CI logic is locally replicable (per code-quality.md)
- If an action needs outputs, use `$GITHUB_OUTPUT` from within the justfile recipe
- Custom actions are only justified when:
  1. The logic is truly GitHub-specific (API calls, permissions)
  2. Reusable across multiple repositories
  3. Needs complex multi-step orchestration that just can't handle

## Prefer Marketplace Actions Over Custom Scripts

**CRITICAL:** When working with GitHub Actions workflows:

1. **NEVER write `actions/github-script` or custom bash when a marketplace action exists**
2. **Search for existing actions first** - Peter Evans, stefanzweifel, and other popular maintainers have actions for most common tasks
3. **Check what's already in use** in the repo before introducing new dependencies
4. **Be consistent** - if refactoring to use a different action, update all similar usages
5. Keep inline bash to a minimum (simple one-liners only)

Common actions already in use:

- `peter-evans/repository-dispatch@v3` - create repository dispatch events
- `peter-evans/create-or-update-comment@v4` - PR comments
- `peter-evans/find-comment@v3` - finding existing comments
- `stefanzweifel/git-auto-commit-action@v5` - git config, add, commit, push

## DRY Principle in Workflows

**CRITICAL:** Keep workflows simple and avoid repetition.

1. **ONE job when possible** - Don't split into multiple jobs just to "organize"
2. **Use conditional expressions** - GitHub expressions (`${{ }}`) can handle complex logic
3. **Wrap context in `toJson()`** - Pass entire context objects instead of extracting fields manually
4. **Mirror existing patterns** - If another workflow handles similar logic cleanly, copy its structure

## Debugging Workflow Issues

**CRITICAL:** When troubleshooting GitHub Actions workflows:

1. **Parse workflow names carefully**
   - "the Claude agent" = `claude-agent.yaml` (repository_dispatch workflow)
   - "CI" = `ci.yaml`
   - "CD" = `cd.yaml`
   - "code review" = `claude-code-review.yml`
   - Don't assume a problem affects ALL workflows when the user mentions a specific one

2. **Compare working vs broken workflows**
   - Before making changes, identify which workflow is broken
   - Find a similar workflow that works correctly
   - Compare the differences systematically
   - Example: `claude-code-review.yml` (works) vs `claude-agent.yaml` (broken)

3. **Ask clarifying questions**
   - If workflow name is ambiguous, ask: "Which workflow specifically?"
   - Don't make broad changes without confirming the scope
   - Example: "git config issues" could be in multiple workflows

4. **Repository dispatch workflows need special auth**
   - Workflows triggered by `repository_dispatch` need the `github-app-auth` action
   - This provides proper bot attribution for commits
   - Example: `claude-agent.yaml` needs this, but `ci.yaml` doesn't (uses `stefanzweifel/git-auto-commit-action`)

5. **Don't fix what isn't broken**
   - If a workflow already works correctly, don't modify it
   - Validate that your changes address the specific reported issue
   - Test the fix against the original problem

## CI Must Pass Before Merging

**CRITICAL:** All CI checks must pass before a PR can be merged. After pushing changes:

1. **Check CI status** using the GitHub API via `GH_TOKEN` (available in environment):
   ```bash
   eval "$(mise activate bash)"
   # Get check runs for latest commit on a PR
   gh api repos/nsheaps/ai-mktpl/commits/<SHA>/check-runs \
     --hostname github.com \
     --jq '.check_runs[] | {name, status, conclusion}'
   ```
2. **Wait for checks to complete** — don't assume a push is done until CI reports back
3. **Fix failures before moving on** — a failing CI is a blocker, not a "nice to have"
4. **Review logs for failures** to understand root cause:
   ```bash
   eval "$(mise activate bash)"
   gh api repos/nsheaps/ai-mktpl/actions/jobs/<JOB_ID>/logs --hostname github.com
   ```

### Common CI Pitfalls

- **Never manually edit `marketplace.json`** — it is auto-generated by the CD workflow on merge to main
- **New plugin `plugin.json` files are OK** — only modifications to existing plugin.json files are blocked (version bumps are automatic)
- **Run `just validate` locally** before pushing to catch validation errors early
- **Run `just lint` locally** before pushing to catch linting issues

### Accessing GitHub API in Web Sessions

In Claude Code web sessions, `gh` is installed via mise but the remote is a local proxy. Use `--hostname github.com` with `gh api` commands, or use `GH_TOKEN` directly:

```bash
eval "$(mise activate bash)"
gh api repos/nsheaps/ai-mktpl/pulls/<PR_NUMBER> --hostname github.com
```

## Secrets Used

- `GITHUB_PAT_TOKEN_NSHEAPS`: For authenticated pushes
- `CLAUDE_CODE_OAUTH_TOKEN`: For Claude Code review

## See Also

- [Plugin Development](../plugin-development.md) - Plugin structure requirements
- [Versioning Rules](../versioning.md) - When version bumps are required
