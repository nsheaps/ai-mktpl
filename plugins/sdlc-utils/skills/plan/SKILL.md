---
name: plan
description: >
  Planning and requirements for software development. Use when the user asks to
  "write a spec", "create a specification", "define requirements", "create a
  feature spec", "draft requirements", "iterate on a spec", "refine a spec",
  "break down a task", "plan implementation", or mentions specifications,
  technical requirements, or task breakdown. Guides iterative specification
  development through research, review, and refinement cycles rather than
  one-shot generation.
---

# Planning and Requirements

Write technical specifications through iterative refinement. Each spec is a
combined document covering both _Problem & Requirements_ (what and why) and
_Technical Design_ (how). Never attempt to produce a complete specification in
one pass. Instead, start with the smallest meaningful definition and expand
through repeated cycles of research, drafting, review, and refinement.

## Core Principle: Iterative Over One-Shot

Specifications written in one pass suffer from blind spots, unstated
assumptions, and missing edge cases. The iterative approach treats a spec as a
living document that grows in fidelity through deliberate cycles.

**The cycle:**

```
Seed -> Draft -> Research -> Review -> Refine -> (repeat until sufficient)
```

Each pass through the cycle adds detail, resolves ambiguity, and surfaces
new questions. Stop iterating when the spec is actionable enough for the
next phase (design, implementation, or review).

## Workflow

### Phase 1: Seed (Smallest Viable Definition)

Start with a one-paragraph problem statement. Capture only:

1. **What problem exists** (1-2 sentences)
2. **Who is affected** (developers, users, systems)
3. **Why it matters now** (urgency or opportunity)

Do NOT attempt to define solutions, features, or acceptance criteria yet.
The seed exists to anchor all future iteration.

### Phase 2: First Draft (Skeleton)

Expand the seed into a skeleton spec using the template structure in
`references/spec-template.md`. Fill in only what is known with confidence.
Mark unknowns explicitly with `[TBD]` or `[NEEDS RESEARCH]`.

Key sections to draft first:

- Problem statement (expand from seed)
- Affected components / systems
- Success metrics (even rough ones)
- High-level scope (what's in, what's explicitly out)

Sections to leave sparse:

- Detailed requirements (add in later passes)
- Technical considerations (add after solution direction is clearer)
- Task breakdown (add in Phase 3+)

### Phase 3: Research Pass

Before adding detail, investigate:

1. **Prior art** - Search the codebase, existing docs, and external sources
   for related work, similar features, or prior attempts
2. **Context** - Ask clarifying questions about constraints and priorities.
   Use `AskUserQuestion` for focused queries.
3. **Technical feasibility** - Explore relevant code, APIs, and
   dependencies to understand what's possible and what's hard
4. **Industry patterns** - Use documentation search to find how others
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

### Phase 5: Task Breakdown

Once the spec has enough fidelity, decompose requirements into implementable
tasks. Each task should be:

- Small enough for a single PR
- Independently testable
- Clearly ordered by dependency

Organize tasks by priority (must-have, should-have, nice-to-have) or by
component grouping.

### Phase 6: Next Steps

After the spec and tasks are drafted, define explicit next steps:

1. **Review** - Who needs to approve this?
2. **Implementation plan** - Break tasks into ordered work items
3. **Open questions** - What remains unresolved?

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

If the target location uses a different convention, adapt to that structure
while maintaining the iterative process.

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
| Vague requirements         | Use specific, testable acceptance criteria     |
| Solution-first thinking    | Define the problem before proposing solutions  |
| Skipping research          | Always investigate before adding detail        |
| Gold-plating               | Stop when actionable for the next phase        |
| Orphaned specs             | Always define next steps and ownership         |

## Additional Resources

### Reference Files

- **`references/spec-template.md`** - Complete spec template with all sections
  and guidance for filling each one. Copy this as a starting point for new
  specs.

### External References

- [Shape Up (Basecamp)](https://basecamp.com/shapeup) - Iterative development
  methodology
- [INVEST Criteria](<https://en.wikipedia.org/wiki/INVEST_(mnemonic)>) -
  Qualities of good work items (Independent, Negotiable, Valuable,
  Estimable, Small, Testable)
