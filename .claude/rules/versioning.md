# Version Management

## Semantic Versioning Required

Every plugin change requires a version bump:

- **Patch (x.y.Z)**: Bug fixes, non-breaking changes
- **Minor (x.Y.0)**: New features, backwards compatible
- **Major (X.0.0)**: Breaking changes

## Version Bumps on Merge to Main

Version bumps and `marketplace.json` regeneration happen **on merge to `main`**, not in PRs. This avoids the constant cross-PR merge conflicts that occur when every PR rewrites the shared `marketplace.json` and bumps `plugin.json`.

### In a PR (preview only)

The CD workflow's `version-preview` job:

1. Detects plugins with code changes (diffed against the PR base branch)
2. Computes what the version bump **would** be — in the working tree only, never committed
3. Posts/updates a sticky PR comment with the version table
4. Emits a GitHub `::notice` annotation on each affected `plugin.json` showing the pending bump (e.g. `my-plugin: 1.2.3 → 1.2.4 will be applied on merge`)

Nothing is committed or pushed to the PR branch.

### On merge to main

The CD `bump-and-update-marketplace` job:

1. Detects changed plugins (relative to the `cd/last-release` tag)
2. Auto-bumps each (patch increment) unless already manually bumped to a higher version
3. Regenerates `marketplace.json`
4. Commits and pushes the bumps + marketplace metadata with `[skip ci]`

### Manual Version Bumps

You **can** manually edit `plugin.json` to set a higher version (e.g., minor or major bump). The auto-bump respects manual bumps — it only bumps if the version hasn't already been increased above the base. The PR preview labels these as "Already bumped".

### New Plugins

New `plugin.json` files (for brand new plugins) are always allowed. The `validate-claude-config` task treats a plugin that exists in `plugins/` but isn't yet in `marketplace.json` as a warning, not an error.

## Commit Message Format

Use conventional commits:

- `feat:` - New features
- `fix:` - Bug fixes
- `chore:` - Maintenance tasks
- `docs:` - Documentation updates

**NEVER** manually add `[skip ci]` to commit messages — see [CI/CD Conventions](ci-cd/conventions.md#never-manually-skip-ci) for details.

## See Also

- [Plugin Development](plugin-development.md) - Structure requirements
- [CI/CD Conventions](ci-cd/conventions.md) - Version check workflow details
