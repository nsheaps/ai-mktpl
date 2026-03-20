# Spec-Driven Development: Building Production-Ready Software with AI — orchestrator.dev

**URL**: https://orchestrator.dev/blog/2025-12-16-spec_driven_dev_article/
**Date read**: 2026-03-20

## Key Takeaways

- Four-phase workflow: **Specify → Plan → Tasks → Implement**
- Phase 1 (Specify): Define user journeys, business requirements, success criteria _without_ technical details (WHAT and WHY, not HOW)
- Phase 2 (Plan): Create technical architecture, select stack, identify dependencies
- Phase 3 (Tasks): Break into small, independently executable work items with clear dependencies
- Phase 4 (Implement): AI agents execute tasks sequentially, developers review focused changes
- **Constitution file** defines project-wide principles (architecture patterns, coding standards, security requirements)
- Acceptance criteria embedded directly in specs ensure test coverage
- Edge cases explicitly documented in specifications
- Artifact sizes: specs 100-300 lines, plans 200-400 lines, task list granular with file paths

## Relevance to rest-owl Plugin

This maps very closely to our Phase 2 → Phase 5 flow. Key differences:

1. **Constitution file** — We don't have this yet. Our Phase 4 (Architecture) produces architectural decisions, but a separate "constitution" that constrains all generated code would be valuable. It would go into the project's CLAUDE.md or similar.
2. **Task granularity** — Their task breakdown specifies exact file paths. Our Phase 5 (Implementation Plan) should be more granular — listing specific files to create/modify per milestone.
3. **Separation of WHAT from HOW** — Their Phase 1 is requirements-only (no tech). Our Phase 2 mixes feature specs with some technical data model definitions. Consider whether to separate these more cleanly.
4. **Spec sizes** — 100-300 lines for specs is a useful guideline. Our feature spec could grow much larger; consider splitting per domain.

## Design Implication

Add a "constitution" or "project rules" artifact to Phase 4 that gets written to the project's CLAUDE.md or equivalent. This ensures all subsequent AI-generated code follows consistent patterns.
