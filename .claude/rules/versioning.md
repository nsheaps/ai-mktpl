# Version Management

## Semantic Versioning Required

Every plugin change requires a version bump:

- **Patch (x.y.Z)**: Bug fixes, non-breaking changes
- **Minor (x.Y.0)**: New features, backwards compatible
- **Major (X.0.0)**: Breaking changes

## NEVER Manually Edit plugin.json

**CRITICAL:** Do NOT manually modify existing `plugin.json` files. The CI `check-version-files` job blocks all manual modifications to existing `plugin.json` files — including version bumps.

Version bumps are handled automatically by the CD pipeline. If you modify a plugin's code, settings, hooks, or docs, the version bump will be applied automatically on merge to main.

New `plugin.json` files (for brand new plugins) are allowed.

## Version Check Workflow

The `cd.yaml` workflow enforces versioning:

1. Detects changed plugins in PRs
2. Compares versions between base and head
3. Fails if version not bumped
4. Suggests appropriate version bump

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
