# Spec-Driven Development: When Architecture Becomes Executable — InfoQ

**URL**: https://www.infoq.com/articles/spec-driven-development/
**Date read**: 2026-03-20

## Key Takeaways

- SDD operates through **five integrated layers** forming a closed-loop control system:
  1. Specification Layer — declarations of system intent
  2. Generation Layer — transforms specs to executable code
  3. Artifact Layer — generated outputs (regenerable, disposable)
  4. Validation Layer — continuous enforcement via contract tests, schema validation, drift detection
  5. Runtime Layer — operational system constrained by specs

- **Specification is the source of truth** — implementations are "continuously derived, validated, and regenerated to conform"
- Validation as build gates: invalid payloads rejected at build time, deployment, and CI
- **Drift detection** identifies divergences between declared intent and observed behavior
- "SpecOps Discipline" — specs receive version control, peer review, and operational rigor equivalent to source code
- Breaking changes require explicit human approval

## Relevance to rest-owl Plugin

This is the most architecturally rigorous SDD model. Key insights for our plugin:

1. **Specs as source of truth, code as artifact** — Our Phase 2 specs should be treated as the authoritative definition. If code diverges from spec, that's a bug in the code, not a need to update the spec.
2. **Drift detection** — Phase 6 validation should include not just "does it work" but "does it match the spec." Visual regression testing does this for UI. We need the equivalent for behavior (acceptance tests derived directly from spec acceptance criteria).
3. **Regenerable artifacts** — Frame the generated code as something that _could_ be regenerated from the spec. This mindset keeps specs up to date.
4. **Closed-loop control** — The phases should feed back. If implementation reveals spec gaps, update the spec first, then regenerate.

## Design Implication

Add a "spec conformance" step in Phase 6 that explicitly maps each acceptance criterion from Phase 2 to a passing test. This closes the loop between specification and validation.
