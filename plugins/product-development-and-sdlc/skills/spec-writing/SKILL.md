---
name: Spec Writing
description: >
  This skill should be used when the user asks to "write a spec", "create a
  specification", "write user stories", "define requirements", "write a
  product spec", "create a feature spec", "draft requirements", "iterate on
  a spec", "refine a spec", "flesh out requirements", "write a PRD", "create
  a product requirements document", or mentions specifications, product
  requirements, user stories, or feature requirements. Guides iterative
  specification development through research, review, and refinement cycles
  rather than one-shot generation.
version: 0.2.0
---

# Spec Writing

Write specifications and user stories through iterative refinement. Each spec
is a combined document covering both *Problem & Requirements* (what and why) and
*Technical Design* (how). Never attempt to produce a complete specification in
one pass. Instead, start with the smallest meaningful definition and expand
through repeated cycles of research, drafting, review, and refinement.

## Core Principle: Iterative Over One-Shot

Specifications written in one pass suffer from blind spots, unstated
assumptions, and missing edge cases. The iterative approach treats a spec as a
living document that grows in fidelity through deliberate cycles.

**The cycle:**

```
Seed → Draft → Research → Review → Refine → (repeat until sufficient)
```

Each pass through the cycle adds detail, resolves ambiguity, and surfaces
new questions. Stop iterating when the spec is actionable enough for the
next phase (design, implementation, or stakeholder review).

## Workflow

### Phase 1: Seed (Smallest Viable Definition)

Start with a one-paragraph problem statement. Capture only:

1. **What problem exists** (1-2 sentences)
2. **Who has this problem** (target user/persona)
3. **Why it matters now** (urgency or opportunity)

Do NOT attempt to define solutions, features, or acceptance criteria yet.
The seed exists to anchor all future iteration.

### Phase 2: First Draft (Skeleton)

Expand the seed into a skeleton spec using the template structure in
`references/spec-template.md`. Fill in only what is known with confidence.
Mark unknowns explicitly with `[TBD]` or `[NEEDS RESEARCH]`.

Key sections to draft first:

- Problem statement (expand from seed)
- Target users / personas
- Success metrics (even rough ones)
- High-level scope (what's in, what's explicitly out)

Sections to leave sparse:

- Detailed requirements (add in later passes)
- Technical considerations (add after solution direction is clearer)
- User stories (add in Phase 3+)

### Phase 3: Research Pass

Before adding detail, investigate:

1. **Prior art** - Search the codebase, existing docs, and external sources
   for related work, similar features, or prior attempts
2. **User context** - Ask the user clarifying questions about personas,
   constraints, and priorities. Use `AskUserQuestion` for focused queries.
3. **Technical feasibility** - Explore relevant code, APIs, and
   dependencies to understand what's possible and what's hard
4. **Competitive/industry patterns** - Use web search to find how others
   solve the same problem

Document findings inline in the spec or in a companion research file.

### Phase 4: Review and Refine

After each research pass, review the draft against these criteria:

| Criterion        | Question to ask                                     |
| ---------------- | --------------------------------------------------- |
| Clarity          | Could someone unfamiliar implement from this?       |
| Completeness     | Are there gaps marked [TBD] that can now be filled? |
| Consistency      | Do requirements contradict each other?              |
| Testability      | Can each requirement be verified?                   |
| Scope discipline | Is anything included that shouldn't be?             |

Refine the document, then decide:

- **More iteration needed?** Return to Phase 3 with specific research goals
- **Sufficient for next step?** Proceed to Phase 5

### Phase 5: User Stories

Once the spec has enough fidelity, decompose requirements into user stories.
Follow the format:

```
As a [persona], I want to [action] so that [benefit].
```

**Acceptance criteria** for each story should be concrete and testable:

```
Given [context], when [action], then [expected result].
```

Organize stories by priority (must-have, should-have, nice-to-have) or by
epic/theme grouping. Keep stories small enough to implement in a single PR.

### Phase 6: Next Steps

After the spec and stories are drafted, define explicit next steps:

1. **Stakeholder review** - Who needs to approve this?
2. **Design phase** - What designs or prototypes are needed?
3. **Implementation plan** - Break stories into tasks with ordering
4. **Open questions** - What remains unresolved?

## File Organization

Store specs according to the project's spec conventions:

```
docs/specs/draft/<spec-name>.md       # Initial drafts
docs/specs/reviewed/<spec-name>.md    # After review/approval
docs/specs/in-progress/<spec-name>.md # During implementation
docs/specs/live/<spec-name>.md        # Actively used
docs/specs/deprecated/<spec-name>.md  # Outdated but referenced
docs/specs/archive/<spec-name>.md     # No longer in use
```

If the target location uses a different convention (e.g., an Obsidian vault
or ideas directory), adapt to that structure while maintaining the iterative
process.

## Iteration Guidelines

- **Minimum 2 passes** before considering a spec "ready for review"
- **Each pass should have a specific goal** (e.g., "flesh out error cases",
  "add technical constraints", "define metrics")
- **Ask questions early and often** rather than assuming
- **Prefer concrete examples** over abstract descriptions
- **Include diagrams or flow descriptions** when they clarify interactions
- **Reference external sources** with links for traceability

## Anti-Patterns to Avoid

| Anti-Pattern               | Instead                                       |
| -------------------------- | --------------------------------------------- |
| Writing everything at once | Start with seed, iterate to add detail        |
| Vague requirements         | Use specific, testable acceptance criteria    |
| Solution-first thinking    | Define the problem before proposing solutions |
| Skipping research          | Always investigate before adding detail       |
| Gold-plating               | Stop when actionable for the next phase       |
| Orphaned specs             | Always define next steps and ownership        |

## Additional Resources

### Reference Files

- **`references/spec-template.md`** - Complete spec template with all sections
  and guidance for filling each one. Copy this as a starting point for new
  specs.

### External References

- [Shape Up (Basecamp)](https://basecamp.com/shapeup) - Iterative product
  development methodology
- [Writing Good User Stories](https://www.mountaingoatsoftware.com/agile/user-stories)
  - Mike Cohn's user story guidance
- [INVEST Criteria](<https://en.wikipedia.org/wiki/INVEST_(mnemonic)>) -
  Qualities of good user stories (Independent, Negotiable, Valuable,
  Estimable, Small, Testable)
