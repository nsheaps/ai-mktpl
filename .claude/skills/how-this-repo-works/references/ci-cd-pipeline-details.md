# CI/CD Pipeline Details

Supplementary reference for the `how-this-repo-works` skill. See `../SKILL.md` for the overview.

## Workflow Files

| File                                          | Purpose                                    |
| --------------------------------------------- | ------------------------------------------ |
| `.github/workflows/ci.yaml`                   | Lint, validate, block manual version edits |
| `.github/workflows/cd.yaml`                   | Version bump + marketplace update on main  |
| `.github/workflows/claude-code-review.yaml`   | AI code review on PRs                      |
| `.github/workflows/claude-agent.yaml`         | Claude agent automation                    |
| `.github/workflows/claude-agent-trigger.yaml` | Trigger for claude agent workflow          |

## Composite Actions

| Action                  | Location                                            | Used By          |
| ----------------------- | --------------------------------------------------- | ---------------- |
| `detect-plugin-changes` | `.github/actions/detect-plugin-changes/action.yaml` | cd.yaml          |
| `update-marketplace`    | `.github/actions/update-marketplace/action.yaml`    | cd.yaml          |
| `lint-files`            | `.github/actions/lint-files/action.yaml`            | ci.yaml          |
| `validate-plugins`      | `.github/actions/validate-plugins/action.yaml`      | ci.yaml          |
| `github-app-auth`       | `.github/actions/github-app-auth/`                  | ci.yaml, cd.yaml |

## CI Pipeline Detail (ci.yaml)

### Triggers

- Pull requests (any branch)
- Push to `main`
- Manual `workflow_dispatch`

### Concurrency

Group: `ci-${{ github.ref }}` with cancel-in-progress. Prevents stacking runs on the same ref.

### Job: check-version-files (PRs only)

Prevents manual edits to version-managed files. Diffs the PR against base branch for:

- `plugins/*/.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`

If any are changed, the job fails with instructions to revert:

```bash
git checkout origin/<base> -- plugins/*/.claude-plugin/plugin.json .claude-plugin/marketplace.json
```

### Job: lint

1. Checkout code
2. Authenticate as GitHub App (for push permission)
3. Install tools via mise
4. Run `just lint` through the `lint-files` composite action with `fix: true`
5. If files changed or lint failed, auto-commit fixes with `stefanzweifel/git-auto-commit-action`
6. Exit 1 so the job fails (next push triggers a re-run with clean state)

### Job: validate

1. Checkout code
2. Install tools via mise
3. Run `claude plugin validate` on marketplace.json and every plugin.json

## CD Pipeline Detail (cd.yaml)

### Triggers

Push to `main` or PR when files in these paths change:

- `plugins/**`
- `.github/workflows/cd.yaml`
- `.github/actions/detect-plugin-changes/**`

Explicitly excluded (to prevent infinite loops):

- `plugins/*/.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`

### Concurrency

Group: `cd-${{ github.ref }}` with cancel-in-progress.

### Job: preview-version-bump (PRs only)

1. Checkout with full history (`fetch-depth: 0`)
2. Fetch base branch
3. Run `just detect-plugin-changes` via composite action
4. Post a sticky PR comment (`marocchino/sticky-pull-request-comment`) with header `plugin-versions` showing a markdown table of plugin name, current version, bump type, and new version.

### Job: bump-and-update-marketplace (main only)

Authentication: Uses a GitHub App (not GITHUB_TOKEN) so that pushed commits can trigger other workflows.

Steps in order:

1. **Checkout** with full history, `persist-credentials: false`
2. **GitHub App auth** for push access
3. **Install mise tools** and **yarn dependencies**
4. **Detect changes** (`base-ref: HEAD~1`) -- The `detect-plugin-changes` action runs `just detect-plugin-changes` which:
   - Iterates `plugins/*`
   - Diffs each plugin dir against `HEAD~1`
   - Excludes `CHANGELOG.md` and `plugin.json` from diff consideration
   - Outputs JSON with: `has_changes`, `plugins` (space-separated names), `plugins_json`, `report_md`
5. **Bump versions** (if changes detected) -- Loops over changed plugin names, runs `yarn exec release-it --ci` in each plugin dir. This:
   - Reads current version from `plugin.json`
   - Applies patch increment
   - Writes new version back to `plugin.json`
   - Runs `prettier --write` on plugin.json (via `after:bump` hook)
6. **Lint** -- `just lint` ensures everything is formatted
7. **Commit version bumps** -- `chore: bump plugin versions [skip ci]`, targeting `plugins/*/.claude-plugin/plugin.json` and `plugins/*/CHANGELOG.md`, with `skip_push: true`
8. **Update marketplace** -- `just update-marketplace` which:
   - Reads each `plugins/*/.claude-plugin/plugin.json`
   - Extracts name, version, description, author, keywords
   - Infers category (git vs utility) from plugin name
   - Infers tags from presence of `commands/` and `skills/` dirs
   - Rebuilds `.claude-plugin/marketplace.json` with plugins sorted by name
   - Runs `just lint-fix` at the end
9. **Lint again** -- Ensures marketplace.json formatting
10. **Commit marketplace** -- `chore: update marketplace metadata [skip ci]`, targeting `.claude-plugin/marketplace.json`, with `skip_push: true`
11. **Push** -- Single `git push` sends both commits at once

## Loop Prevention

The CD workflow avoids infinite loops through two mechanisms:

1. **Path exclusions in triggers**: `!plugins/*/.claude-plugin/plugin.json` and `!.claude-plugin/marketplace.json` ensure that version bump and marketplace commits don't re-trigger CD.
2. **[skip ci] in commit messages**: Both auto-commits include `[skip ci]` which GitHub Actions respects.

## release-it Configuration

Base config (`.release-it.base.json`):

- `git.commit: false` -- CI does the committing
- `git.tag: false` -- No tags created
- `git.push: false` -- CI does the pushing
- `npm.publish: false` -- Not an npm package
- `github.release: false` -- No GitHub releases
- `increment: "patch"` -- Always patch bump
- `hooks.after:bump` -- `prettier --write .claude-plugin/plugin.json || true`

Per-plugin config (`.release-it.js`):

- Extends the base config
- Configures `@release-it/bumper` to read/write `plugin.json`

## References

- [release-it docs](https://github.com/release-it/release-it)
- [@release-it/bumper docs](https://github.com/release-it/bumper)
- [stefanzweifel/git-auto-commit-action](https://github.com/stefanzweifel/git-auto-commit-action)
- [marocchino/sticky-pull-request-comment](https://github.com/marocchino/sticky-pull-request-comment)
- [jdx/mise-action](https://github.com/jdx/mise-action)
