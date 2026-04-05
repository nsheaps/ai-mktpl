# Version Management

## Semantic Versioning Required

Every plugin change requires a version bump:

- **Patch (x.y.Z)**: Bug fixes, non-breaking changes
- **Minor (x.Y.0)**: New features, backwards compatible
- **Major (X.0.0)**: Breaking changes

## Version Bumps in PRs

Version bumps happen **in PRs**, not on merge to main. The CD workflow's `auto-version-bump` job:

1. Detects plugins with code changes
2. Compares the PR's version against the base version
3. If not already bumped, auto-bumps (patch increment) and pushes back to the PR branch
4. If manually bumped to a higher version, preserves the manual bump

### Manual Version Bumps

You **can** manually edit `plugin.json` to set a higher version (e.g., minor or major bump). The auto-bump will respect manual bumps — it only bumps if the version hasn't been increased yet.

### What Happens on Merge to Main

The CD `bump-and-update-marketplace` job runs on main and:

1. Checks if each changed plugin was already bumped in the PR
2. Only bumps plugins that still need it (safety net)
3. Regenerates `marketplace.json`

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
