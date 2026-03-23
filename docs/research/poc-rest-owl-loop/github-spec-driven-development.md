# Spec-Driven Development: From Rough Idea to Detailed Specification

## Sources

- **GitHub Blog - Spec Kit**: https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/
- **Martin Fowler - SDD Tools**: https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html
- **Augment Code Guide**: https://www.augmentcode.com/guides/what-is-spec-driven-development
- **JetBrains Junie**: https://blog.jetbrains.com/junie/2025/10/how-to-use-a-spec-driven-approach-for-coding-with-ai/
- **Kiro (AWS)**: https://kiro.dev/blog/kiro-and-the-future-of-software-development/
- **InfoQ**: https://www.infoq.com/articles/spec-driven-development/
- **MM Software**: https://www.mm-software.com/en/more-the-newsroom/detail/how-companies-can-prevent-ai-project-failures-1/

## What Is Spec-Driven Development (SDD)?

A development paradigm where well-crafted software requirement specifications serve as the primary development artifact from which code is derived. Specifications drive the implementation rather than serving as passive documentation.

## The Core Workflow

1. **Specify**: Share your system idea with an AI agent (the _what_ and _why_). Agent generates a detailed specification.
2. **Plan**: Define the technical approach -- frameworks, tools, languages.
3. **Tasks**: Break everything into small, structured work packages. Instead of "build authentication," you get "create a user registration endpoint that validates email format."
4. **Implement**: Agent implements each work package.

## What Makes a Good Specification?

- Input/output mappings
- Preconditions/postconditions
- Invariants and constraints
- Interface types
- Integration contracts
- Sequential logic/state machines
- Domain-oriented ubiquitous language (business intent, not tech-bound)

## SDD vs Vibe Coding

SDD is explicitly positioned as the antidote to vibe coding's weaknesses:

- Vibe coding: "describe goal, get code back, often looks right but doesn't quite work"
- SDD: "write complete requirements and technical specs before passing to AI agent"

The spec is described as a "version-controlled, human-readable super prompt" (Kiro).

## Key Tools

- **GitHub Spec Kit**: Open-source toolkit making spec the center of engineering process
- **Kiro (AWS)**: IDE that generates specs from rough ideas, then implements from specs
- **JetBrains Junie**: Refines high-level requirements into detailed development plans

## Success Rates and Limitations

- Success rate across all requirements including tests: roughly 50-90%
- After a few feedback iterations, quality gains plateau
- The term "spec-driven development" isn't well-defined yet and is already semantically diffused
- Skepticism about heavy up-front spec design vs. small iterative steps

## Relevance to Plugin Development

1. **SDD is literally the "draw the rest of the owl" solution** -- it fills in the middle between idea and implementation with explicit, structured specifications.
2. **The Specify -> Plan -> Tasks -> Implement workflow is a concrete pattern** a plugin could implement.
3. **GitHub Spec Kit is open source** -- could be studied or integrated.
4. **The spec becomes a reusable artifact** -- version-controlled, reviewable, improvable.
5. **A Claude Code plugin could implement SDD natively** -- generate specs from conversation, store them as files, use them to drive implementation.

## Criticism

- 50-90% success rate means significant manual intervention is still needed.
- Heavy up-front specification may conflict with agile/iterative approaches.
- There's a risk of "specification theater" -- spending time on specs that don't actually improve outcomes.
- The term is already becoming diluted; every AI coding tool claims to be "spec-driven."
- Martin Fowler's team expresses skepticism about the maturity of these tools.
