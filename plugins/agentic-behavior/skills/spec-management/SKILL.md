---
name: spec-management
description: >
  This skill should be used when creating, updating, or reviewing specifications
  during the PR process. Trigger phrases: "write a spec", "update the spec",
  "does this PR have a spec", "add a spec to this PR", "review the spec",
  "spec-driven development", or when making plugin changes that need specification
  documentation.
---

# Spec Management

Specifications are natural-language descriptions of features that serve as the
source of truth for PM, PO, QA, QE, and ops. Think of them as natural-language
unit and integration tests -- they define what a feature does, why it exists, and
how to verify it works.

## Core Rules

1. **Every plugin change PR must include a spec update in the same PR.** If a PR
   changes plugin behavior, the corresponding spec must be created or updated as
   part of that PR.
2. **Specs are source of truth.** Code implements what the spec describes. If
   code and spec disagree, the spec wins (update the code or update the spec
   with approval).
3. **PRs must be developed against merged specs.** Specs should exist on the
   default branch before implementation starts. Exception: draft specs may be
   included in the PR that implements the feature, but must be reviewed as part
   of the PR.

## Directory Structure

Specs live co-located with the plugin they describe:

```
plugins/<plugin-name>/docs/specs/
  draft/          # Initial drafts and brainstorming
  reviewed/       # Reviewed and approved
  in-progress/    # Currently being implemented
  live/           # Finalized and actively in use
  deprecated/     # Outdated but still referenced
  archive/        # No longer in use
```

This follows the convention defined in `common-sense/rules/mantras-and-incremental-development.md`.

## Spec Format

Each spec is a single markdown file with YAML frontmatter, a reader guide, and
content sections that mix narrative with testable Given/When/Then scenarios.

### Frontmatter

```yaml
---
title: "<Feature or Rule Name>"
status: draft | reviewed | in-progress | live | deprecated | archived
version: "0.1.0"
created: YYYY-MM-DD
updated: YYYY-MM-DD
pr: "<owner/repo#N or URL>" # PR that introduced or last updated this spec
---
```

### Reader Guide

Immediately after frontmatter, include a short section explaining who the spec
is for and how to read it:

```markdown
## Reader Guide

**Audience:** PM, PO, QA, QE, ops, and engineers implementing the feature.

**How to read this spec:** Narrative sections describe intent and context.
`Given/When/Then` blocks define testable acceptance criteria. If you are
reviewing for correctness, focus on the Given/When/Then blocks.
```

### Content Sections

Specs use a **combined format** -- Problem & Requirements (what and why) plus
Technical Design (how) in a single document. Do NOT separate these into distinct
"PRD" and "spec" documents.

Typical sections:

1. **Problem** -- What problem does this solve? Who is affected?
2. **Requirements** -- What must be true for the feature to be complete?
3. **Design** -- How does the implementation work? Key decisions and trade-offs.
4. **Acceptance Criteria** -- Given/When/Then scenarios covering happy path,
   edge cases, and error conditions.
5. **References** -- Links to PRs, issues, discussions, or external docs.

### Given/When/Then Format

Use this format for testable criteria:

```markdown
### Scenario: <descriptive name>

**Given** <precondition>
**When** <action or trigger>
**Then** <expected outcome>
```

Group related scenarios under a shared heading. Each scenario should be
independently verifiable.

## Size Guidelines

- Aim to keep specs under ~500 lines.
- If a spec grows beyond that, split into a **parent spec** (scope and
  requirements) and **child specs** (technical details per component).
- Child specs reference the parent via frontmatter or a "Parent Spec" section.

## Workflow

### Creating a new spec

1. Create the file at `plugins/<plugin>/docs/specs/draft/<spec-name>.md`
2. Fill in frontmatter with `status: draft`
3. Write Problem, Requirements, and initial acceptance criteria
4. Add the spec to the same PR as the implementation (or a preceding PR)

### Updating an existing spec

1. Find the current spec in its lifecycle directory (draft/reviewed/live/etc.)
2. Update content and bump `updated` date in frontmatter
3. If the spec moves lifecycle stages, move the file to the new directory
4. Include the spec update in the same PR as the code change

### Reviewing a spec

When reviewing a PR that includes a spec:

- Verify Given/When/Then scenarios cover happy path AND edge cases
- Check that the spec matches what the code actually implements
- Confirm the spec is understandable by non-engineers (PM/QA audiences)
- Verify size is under ~500 lines; suggest splitting if larger

## Anti-Patterns

| Anti-Pattern                                   | Instead                                      |
| ---------------------------------------------- | -------------------------------------------- |
| PR changes plugin behavior with no spec update | Include spec update in the same PR           |
| Separate PRD and technical spec documents      | Use combined format in one file              |
| Spec only has narrative, no testable criteria  | Add Given/When/Then acceptance criteria      |
| 800-line mega-spec                             | Split into parent + child specs              |
| Spec lives in a random location                | Co-locate under `plugins/<name>/docs/specs/` |
| Starting implementation before spec exists     | Write at least a draft spec first            |

## References

- [Spec directory conventions](../../../common-sense/rules/mantras-and-incremental-development.md) -- defines the draft/reviewed/in-progress/live/deprecated/archive lifecycle
- Handler feedback on specs -- originated from org Discord discussion on requiring specs for every plugin change PR and developing PRs against merged specs
