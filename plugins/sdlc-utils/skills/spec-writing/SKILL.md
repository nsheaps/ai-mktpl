---
name: spec-writing
description: >
  Specification writing and lifecycle management for software development.
  Use when the user asks to "write a spec", "create a specification", "document
  requirements", "spec out a feature", "manage a spec through its lifecycle",
  "move a spec to live", "archive a spec", "update a spec", or "verify
  implementation against a spec". Covers creating specs from requirements,
  managing the spec lifecycle (draft → reviewed → in-progress → live → deprecated
  → archive), keeping specs as living documents, and using specs for verification.
---

# Specification Writing

Guide for writing, maintaining, and managing specifications through their
complete lifecycle. Specifications are a critical tool for ensuring alignment
between requirements, design, and implementation.

## Core Principles

1. **Specs are living documents** — Update them as you learn more during
   implementation, not just before
2. **Combined format** — Problem/Requirements + Technical Design in one
   document (not separate PRD and tech spec)
3. **Reasonable size** — Target ~500 lines; split into parent + child specs if
   larger
4. **Spec-driven iteration** — Each SDLC cycle should review and update the
   spec to reflect new understanding
5. **Clear lifecycle** — Specs move through defined states to track maturity
   and usage

## Specification Lifecycle

Specifications move through six states, each with a distinct purpose and
location:

### Draft: `docs/specs/draft/<spec-name>.md`

**Purpose:** Initial exploration and brainstorming

**When to use:**

- First attempt at defining a feature or requirement
- Exploring multiple approaches
- Iterating on the problem definition
- Sketching out technical direction before committing

**Characteristics:**

- May be incomplete with `[TBD]` and `[NEEDS RESEARCH]` sections
- Used for internal refinement and discussion
- Not yet formally reviewed

**Next step:** Move to `reviewed/` after review and approval

### Reviewed: `docs/specs/reviewed/<spec-name>.md`

**Purpose:** Formally approved specifications ready for implementation

**When to use:**

- Spec has passed review and is approved for work
- Requirements are clear and stable enough for implementation to begin
- Decisions on approach, trade-offs, and scope are finalized

**Characteristics:**

- All `[TBD]` items have been resolved
- Review feedback has been incorporated
- Clear acceptance criteria and success metrics
- Technical design is detailed enough to guide implementation

**Next step:** Move to `in-progress/` when implementation begins

### In-Progress: `docs/specs/in-progress/<spec-name>.md`

**Purpose:** Specifications actively being implemented

**When to use:**

- Implementation work is underway
- Spec may need updates as new information emerges during development
- Tracks decisions made during implementation that affect requirements

**Characteristics:**

- Living document — updated as implementation reveals edge cases or
  constraints
- Notes on implementation decisions and trade-offs made
- May include implementation phase breakdowns or milestone tracking
- Acts as a reference during implementation and review

**Next step:** Move to `live/` when implementation is complete and deployed

### Live: `docs/specs/live/<spec-name>.md`

**Purpose:** Finalized specifications for actively used features

**When to use:**

- Feature is implemented and deployed
- Spec represents the current behavior and requirements
- Used as reference for maintenance, debugging, and new feature planning

**Characteristics:**

- Represents the current, deployed reality
- Should match the actual implementation
- Updated only when the implementation changes (and spec should be updated in
  lockstep)
- Long-lived, stable document

**Next step:** Move to `deprecated/` when feature is phased out (while still in
use), or `archive/` when completely removed

### Deprecated: `docs/specs/deprecated/<spec-name>.md`

**Purpose:** Outdated specifications for features still in use

**When to use:**

- Feature is being phased out but still in production
- A new spec is replacing this one, but the old system is still running
- Historical reference for features no longer being actively developed

**Characteristics:**

- Includes deprecation notice explaining why and timeline for removal
- References the replacement spec (if any)
- Kept for historical continuity and understanding legacy behavior

**Next step:** Move to `archive/` when feature is fully removed

### Archive: `docs/specs/archive/<spec-name>.md`

**Purpose:** Historical reference for removed features

**When to use:**

- Feature has been completely removed from the system
- Kept for historical reference and future archaeology
- Not actively used or referenced

**Characteristics:**

- Includes removal date and reason
- Marked clearly as archived/historical
- May be referenced if that feature is ever reconsidered

## Creating a Specification

### Structure and Format

Use the combined format: **one document containing both Problem & Requirements
and Technical Design**. Do not separate into distinct "PRD" and "tech spec"
documents.

**Recommended sections:**

```markdown
# [Feature Name]

## Problem & Requirements

### Problem Statement

What problem does this solve? Who is affected? Why is it urgent?

### Requirements

What needs to be true? List specific, testable requirements.

### Success Metrics

How will we know this is successful?

### Out of Scope

What deliberately is NOT included?

## Technical Design

### Architecture Overview

High-level system design and component interactions.

### Implementation Details

Specific implementation approach, libraries, patterns, and constraints.

### Error Handling & Edge Cases

What happens when things go wrong?

### Testing Strategy

How will this be tested?

### Migration & Rollout

Any migration steps or phased rollout needed?

## Next Steps

What remains to be done? Who is responsible?
```

See `references/spec-template.md` for a complete template with guidance on
each section.

### Size Guidance

**Target:** 200-500 lines

**If your spec exceeds 500 lines:**

1. Identify the "parent" spec (overall problem, key requirements, success
   metrics)
2. Extract detailed design into "child" specs (one per major component or
   concern)
3. Parent spec references child specs
4. Both move through the lifecycle together, but separately

**Example:**

```
docs/specs/draft/search-feature.md         (parent - 300 lines)
docs/specs/draft/search-indexing.md        (child - 200 lines)
docs/specs/draft/search-query-language.md  (child - 250 lines)
```

## Writing Requirements

Good requirements are **specific, testable, and unambiguous**.

| Poor                          | Better                                       |
| ----------------------------- | -------------------------------------------- |
| "Fast API responses"          | "API responds in <200ms at p95"              |
| "User-friendly interface"     | "Onboarding completes in <3 clicks"          |
| "Robust error handling"       | "Network errors are retried 3x with backoff" |
| "Supports various file types" | "Supports PDF, DOCX, PNG files"              |

## Specification as a Living Document

### During Implementation

As you implement, the spec becomes a reference and record:

1. **Update for discovered constraints:** If implementation reveals a
   constraint not in the spec, document it
2. **Note trade-offs:** If you choose one approach over another, record why
3. **Record edge cases:** If edge cases emerge during implementation, add them
4. **Update timeline:** If milestones change, update the spec
5. **Version the document:** Keep it in sync with actual behavior

### During Code Review

The spec is a checklist for reviewers:

1. Does the implementation match what the spec said?
2. Did implementation decisions diverge from the spec? Is that documented?
3. Are edge cases handled as the spec described?
4. Does the code need to change, or does the spec need to be updated?

### During Maintenance

The spec is the source of truth for behavior:

1. When debugging, refer to the spec to understand intended behavior
2. When fixing bugs, check if they're spec violations or spec inadequacies
3. When planning new features, reference the spec to avoid breaking changes

## Using Specs for Verification

Once implementation is complete, use the spec to verify work:

### Verification Checklist

- [ ] Does each requirement have a corresponding implementation?
- [ ] Can each requirement be verified (manually or with tests)?
- [ ] Are all "out of scope" items correctly excluded?
- [ ] Do success metrics have baseline measurement and target?
- [ ] Have edge cases been tested and handled?
- [ ] Does code review align implementation with spec?

### When Spec and Implementation Diverge

If implementation differs from the spec:

1. **If implementation is correct, spec is wrong** → Update spec to match
   implementation (document why the change was necessary)
2. **If spec is correct, implementation is wrong** → Fix the implementation
   (this is a bug)
3. **If both are partially right** → Negotiate which version is correct and
   update accordingly

Never silently ignore divergence. Always document the decision.

## Spec Review Criteria

### Before Moving from Draft to Reviewed

- [ ] Problem statement is clear and justified
- [ ] Requirements are specific and testable
- [ ] Success metrics are defined
- [ ] Scope is realistic (nothing gold-plated)
- [ ] Technical approach is sound (feasible, follows patterns, no major unknowns)
- [ ] Error cases and edge cases are addressed
- [ ] Implementation timeline is realistic
- [ ] Acceptance criteria are clear enough to verify completion

### Before Moving from Reviewed to In-Progress

- [ ] All review feedback incorporated
- [ ] Ready for implementation to begin
- [ ] Tasks can be broken down and estimated
- [ ] No blocking dependencies or unknowns

### Before Moving from In-Progress to Live

- [ ] Implementation matches spec (or spec is updated to match implementation)
- [ ] All acceptance criteria verified
- [ ] Tests pass
- [ ] Code review complete
- [ ] Feature deployed and validated

## Anti-Patterns to Avoid

| Anti-Pattern                     | Instead                                      |
| -------------------------------- | -------------------------------------------- |
| Writing elaborate specs one-shot | Iterate through draft → review → refine      |
| Separating PRD from tech spec    | Use one combined document                    |
| Specs as decoration              | Living doc, updated as implementation learns |
| Ignoring spec divergence         | Always resolve and document divergence       |
| Specs too long (1000+ lines)     | Split into parent + child specs              |
| Vague requirements               | Specific, measurable, testable criteria      |
| Outdated specs in "live"         | Update immediately when implementation       |
|                                  | changes                                      |
| Specs in wrong directory         | Use correct lifecycle directory              |

## Integration with SDLC Cycle

Each development cycle should review and update the spec:

```
1. Planning → Review and refine spec
2. Design → Update spec with technical decisions
3. Implementation → Keep spec in sync with code
4. Testing → Verify implementation against spec
5. Review → Check spec alignment during code review
6. Deployment → Move spec to "live" (or "deprecated")
7. Maintenance → Treat spec as source of truth
```

## File Organization

Organize specs according to the project structure:

```
docs/specs/
├── draft/           # In exploration/drafting
├── reviewed/        # Approved, ready for implementation
├── in-progress/     # Currently being implemented
├── live/            # Active, deployed features
├── deprecated/      # Phased out but still in use
└── archive/         # Removed, historical reference
```

**File naming:** Use descriptive names: `user-authentication.md`,
`search-indexing.md`, `payment-webhook.md` (not `spec1.md`, `tmp.md`, etc.)

## Additional Resources

### Template

- **`references/spec-template.md`** — Complete spec template with all sections
  and filling guidance. Copy as a starting point for new specs.

### Reference Material

- **Related rule in common-sense plugin:**
  `mantras-and-incremental-development.md` — Defines spec-driven development
  and the spec lifecycle directory structure
- [Shape Up (Basecamp)](https://basecamp.com/shapeup) — Iterative development
  methodology
- [C4 Model](https://c4model.com/) — Architecture diagramming and
  specification
