# Spec-Based Development Rules

## Overview

This plugin enforces spec-based development practices to improve requirements capture and deliverable validation.

## Workflow

### 1. New Feature Requests

When receiving a new feature request:

1. **Explore**: Use the Explore agent to understand relevant codebase areas
2. **Plan**: Use the Plan agent to design the implementation approach
3. **Capture**: Create a spec file with ONLY what the user requested
4. **Commit**: Commit the spec before starting implementation
5. **Implement**: Build the feature according to the spec
6. **Validate**: Verify implementation meets all acceptance criteria
7. **Test**: Add unit tests covering the spec's requirements

### 2. Spec File Management

**Location**: `docs/specs/<feature-name>.md`

**Before updating an existing spec**:

```bash
# Move existing spec to draft
mv docs/specs/feature.md docs/specs/draft/feature.md
```

**Spec content rules**:

- Include ONLY requirements from the user's prompt or clarifications
- Keep it concise and minimal
- No assumptions or scope creep
- Use simple, clear language

### 3. Spec File Format

```markdown
# Feature Name

## Requirements

- [Direct requirements from user prompt]
- [Clarifications from conversation]

## Acceptance Criteria

- [Testable conditions for completion]

## Notes

- [Any relevant context or constraints]
```

### 4. Validation Process

Before marking any task complete:

1. Read the spec file
2. Verify EACH requirement is satisfied
3. Verify EACH acceptance criterion passes
4. Run tests locally
5. Push and let CI validate (don't wait)

### 5. Unit Tests

Most changes should include unit tests that:

- Cover the acceptance criteria from the spec
- Run automatically in CI
- Validate the implementation works as specified

**After pushing**: CI will run tests. Don't wait for completion, but check results when available.

### 6. Commit Order

1. **First commit**: Spec file (before any implementation)
2. **Subsequent commits**: Implementation and tests
3. **Final verification**: Ensure spec requirements are met

## Key Principles

- **Minimal**: Only capture what user requested
- **Explicit**: No implicit requirements or assumptions
- **Testable**: Every requirement should be verifiable
- **Traceable**: Implementation maps back to spec items
