# Version Management

## Semantic Versioning Required

Every plugin change requires a version bump:

- **Patch (x.y.Z)**: Bug fixes, non-breaking changes
- **Minor (x.Y.0)**: New features, backwards compatible
- **Major (X.0.0)**: Breaking changes

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

Append `[skip ci]` to skip CI workflows when needed.
