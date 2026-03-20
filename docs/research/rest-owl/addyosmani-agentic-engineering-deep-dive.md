# Agentic Engineering — Addy Osmani (Deep Dive)

**URL**: https://addyosmani.com/blog/agentic-engineering/
**Date read**: 2026-03-20

## Key Takeaways

### Planning as Foundation

- "You start with a plan. Before prompting anything, you write a design doc or spec."
- Planning breaks complex projects into well-defined tasks and establishes architecture before AI involvement
- This is what distinguishes agentic engineering from vibe coding

### Task Scoping & Review

- "Give the AI agent a well-scoped task from your plan. It generates code. You review with the same rigor you'd apply to a human teammate's PR."
- Human remains architect and quality gatekeeper

### Testing as the Critical Differentiator

- "With a solid test suite, an AI agent can iterate in a loop until tests pass, giving you high confidence"
- Without comprehensive tests, systems become fragile and unreliable
- Testing is what separates professional agentic engineering from amateur vibe coding

### Success Patterns

- Specification quality directly improves AI output
- Comprehensive test suites enable confident delegation
- Clean architecture reduces hallucinations
- **AI rewards good engineering more than traditional coding does**

### Critical Failure Modes

- Skipping design thinking
- Not reviewing diffs or understanding generated code
- Absence of meaningful test coverage
- Treating AI as magic rather than a tool requiring discipline

### Skill Gap Warning

- Agentic engineering **disproportionately benefits senior engineers**
- Junior developers risk building code they cannot debug — "dangerous skill atrophy"

## Relevance to rest-owl Plugin

This validates our entire architecture and highlights one gap:

1. **Review checkpoints** — Our user checkpoints between phases align with "review with same rigor as a PR." But we could be more explicit: after Phase 6 implementation, the user should REVIEW the generated code, not just check if tests pass.
2. **Skill gap danger** — Our plugin makes it easy for anyone to scaffold a project, but the user still needs to understand and maintain the code. Consider adding a "handoff" step at the end that walks the user through the architecture and key decisions so they can maintain it.
3. **Test-first emphasis** — Consider reframing our Phase 6 to write tests BEFORE implementation code, not after. Write the E2E tests from Phase 2 acceptance criteria first, then implement until they pass. This aligns with the "iterate until tests pass" loop.

## Design Implication

Add a Phase 7 or post-build "handoff" step that:

- Walks the user through the architecture decisions
- Explains key code patterns used
- Identifies areas that will need human attention as the project grows
- Warns about the skill gap — you own this code now, understand it
