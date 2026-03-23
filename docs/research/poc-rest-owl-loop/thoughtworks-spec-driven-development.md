# Spec-Driven Development — Thoughtworks

**URL**: https://www.thoughtworks.com/en-us/insights/blog/agile-engineering-practices/spec-driven-development-unpacking-2025-new-engineering-practices
**Date read**: 2026-03-20

## Key Takeaways

- SDD is a development paradigm using well-crafted specs as prompts for AI coding agents
- One of the most important practices to emerge in 2025
- Three phases: **Specify** (analyze requirements → markdown specs), **Review** (iterative human-in-the-loop), **Implement** (specs → code generation)
- Effective specs define: input/output mappings, pre/post conditions, invariants, interface types, integration contracts, state machines
- Uses Given/When/Then scenarios for clarity and determinism
- Reduces AI hallucinations through structured, domain-oriented language
- Bridges vibe coding's spontaneity with engineering rigor

## Relevance to poc-rest-owl-loop Plugin

Our Phase 2 (Feature Spec) directly implements SDD principles. Key enhancements to consider:

1. **Spec format matters** — Use Given/When/Then consistently (we already do this)
2. **Domain-oriented language** — Should define a glossary in Phase 2 (we have this as a section)
3. **Invariants and constraints** — Our specs could be more explicit about system invariants
4. **Spec clarity reduces hallucinations** — The more precise our specs, the better the AI-generated code in Phase 6

## Design Implication

Phase 2 should emphasize that specs are not documentation — they are **executable prompts**. The quality of the spec directly determines the quality of the generated code. Consider adding a "spec quality checklist" that evaluates clarity, determinism, and completeness.
