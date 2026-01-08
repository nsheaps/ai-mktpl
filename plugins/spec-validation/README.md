# Spec Validation Plugin

Spec-based development plugin that captures requirements into spec files and validates deliverables against them.

## Features

- **UserPromptSubmit Hook**: Injects spec-based development guidance for feature requests
- **PostToolUse Hook**: Reminds to validate against specs when updating todos
- **Spec Management Skill**: Manages spec files for requirements capture
- **Development Rules**: Guidelines for spec-based workflow

## Installation

Copy the plugin to your Claude Code plugins directory or add via the marketplace.

## Usage

### Automatic Behavior

When you make a feature request, the plugin:

1. Detects implementation-related prompts
2. Injects guidance to use Explore and Plan agents
3. Prompts creation of spec files before implementation
4. Reminds about validation when updating todos

### Spec File Location

- Active specs: `docs/specs/<feature-name>.md`
- Archived specs: `docs/specs/draft/`

### Workflow

1. **Request**: User describes feature
2. **Explore**: Claude explores relevant code
3. **Plan**: Claude plans implementation
4. **Capture**: Create spec with user's requirements only
5. **Commit**: Commit spec before implementing
6. **Implement**: Build the feature
7. **Validate**: Verify against spec
8. **Test**: Add unit tests for acceptance criteria
9. **Push**: Push and let CI run (don't wait)

## Spec Format

```markdown
# Feature Name

## Requirements
- [Direct requirements from user]

## Acceptance Criteria
- [Testable conditions]

## Notes
- [Clarifications from conversation]
```

## Key Principles

- **Minimal**: Only capture what user explicitly requested
- **No assumptions**: Don't add requirements user didn't ask for
- **Commit first**: Spec committed before implementation
- **Validate**: Check work against spec before completion
- **Test**: Unit tests should cover acceptance criteria

## Directory Structure

```
plugins/spec-validation/
├── .claude-plugin/
│   └── plugin.json
├── hooks/
│   ├── UserPromptSubmit/
│   │   └── capture-requirements.sh
│   └── PostToolUse/
│       └── validate-against-spec.sh
├── rules/
│   └── spec-development.md
├── skills/
│   └── spec-management/
│       └── SKILL.md
└── README.md
```

## Requirements

- `docs/specs/` directory in project
- `docs/specs/draft/` directory for archived specs
- Git for version control
