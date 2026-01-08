---
name: spec-management
description: Manages spec files for requirements capture and validation
---

# Spec Management Skill

## When Claude Activates This Skill

This skill activates when:
- User requests a new feature or implementation
- User asks to modify existing functionality
- A task requires planning before implementation
- Validation against requirements is needed

## What This Skill Enables

### 1. Requirements Capture
- Extract requirements from user prompts
- Create minimal, focused spec files
- Avoid scope creep and assumptions

### 2. Spec File Management
- Create specs in `docs/specs/`
- Move existing specs to `docs/specs/draft/` before updates
- Maintain spec version history

### 3. Implementation Validation
- Verify changes against spec requirements
- Ensure acceptance criteria are met
- Track completion status

## How Claude Uses This Skill

### New Feature Request

1. Use Explore agent to understand codebase
2. Use Plan agent to design approach
3. Create spec file with user's requirements only
4. Commit spec before implementation
5. Implement feature
6. Validate against spec
7. Add unit tests

### Updating Existing Feature

1. Move existing spec to `docs/specs/draft/`
2. Create updated spec with new requirements
3. Commit spec changes
4. Implement changes
5. Validate against updated spec

## Spec File Format

```markdown
# Feature Name

## Requirements
- [User's direct requirements]

## Acceptance Criteria
- [Testable conditions]

## Notes
- [Clarifications only]
```

## Best Practices

1. **Keep specs minimal**: Only what user requested
2. **Commit specs first**: Before any implementation
3. **Validate continuously**: Check spec during development
4. **Test coverage**: Unit tests for acceptance criteria
5. **Don't wait for CI**: Push and continue, check later

## Requirements

- `docs/specs/` directory exists
- `docs/specs/draft/` directory for archived specs
- Git for version control

## Limitations

- Specs only capture explicit requirements
- Does not auto-generate tests
- Requires manual validation
