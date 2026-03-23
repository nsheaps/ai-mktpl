# Martin Fowler (Birgitta Boeckeler): Critical Analysis of SDD Tools

## Source

- **Martin Fowler / Birgitta Boeckeler - "Understanding Spec-Driven Development: Kiro, spec-kit, and Tessl"**: https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html

## Overview

This is a deeply critical, hands-on evaluation of three SDD tools by Birgitta Boeckeler, published on Martin Fowler's site. It's one of the most rigorous assessments available and provides essential counterbalance to the marketing-heavy content from tool vendors.

## Three Levels of SDD

The author distinguishes three implementation levels:

1. **Spec-first**: Specs guide initial development, then are discarded
2. **Spec-anchored**: Specs persist for ongoing feature evolution
3. **Spec-as-source**: Specs become the primary maintained artifact; code is generated from them

## Tool-by-Tool Assessment

### Kiro (AWS)

- Lightweight, intuitive three-step workflow: Requirements -> Design -> Tasks
- But: fixed workflows unsuitable for varying problem sizes
- A small bug generated "4 user stories with 16 acceptance criteria" -- massive overkill

### GitHub Spec Kit

- Customizable, uses a "constitution" to enforce architectural principles
- But: generated excessive markdown files that were "repetitive," "verbose and tedious to review"
- The author states she would **"rather review code than all these markdown files"**

### Tessl

- Only tool pursuing spec-anchored and spec-as-source approaches
- One-to-one spec-to-file mapping reduces LLM interpretation errors
- Most ambitious but also most unproven

## Critical Weaknesses (Across All Tools)

### Workflow Mismatch

Fixed workflows don't fit all problem sizes. Using heavyweight spec processes for small fixes creates absurd overhead.

### Review Burden

SDD doesn't eliminate review -- it shifts it from code review to spec review, and the specs can be MORE tedious to review than code.

### Instruction Non-Compliance

Despite comprehensive specifications, agents frequently ignored instructions or misinterpreted existing code as new specifications, creating duplicates. The spec doesn't guarantee the AI will follow it.

### Unclear Target Users

Documentation doesn't clarify whether SDD suits small fixes, large features, or requires cross-functional teams.

### Semantic Diffusion

The term "spec-driven development" is already poorly defined and experiencing semantic diffusion -- "spec" is becoming synonymous with "detailed prompt."

## The MDD Parallel (Critical Warning)

The author draws concerning parallels to **Model-Driven Development (MDD)**, which promised code generation from specifications but ultimately failed in business applications. MDD "created too much overhead and constraints."

Spec-as-source might inherit **"the downsides of both MDD and LLMs: Inflexibility AND non-determinism."** This is a devastating critique -- combining the rigidity of model-driven approaches with the unpredictability of LLMs.

## The "Verschlimmbesserung" Risk

German word meaning "making something worse while attempting improvement." The author questions whether SDD tools represent genuine improvement or this pattern.

## Overall Assessment

Real-world maturity remains unproven. Extended testing on actual codebases (not tutorial scenarios) is needed. Spec-first approaches have merit but elaborate spec-anchored tools remain questionable.

## Relevance to Plugin Development

1. **This is the most important cautionary source in the research.** Any plugin in this space must address these criticisms directly.

2. **The review burden problem is critical**: If generating specs creates MORE work than it saves, the plugin fails. The plugin MUST generate concise, reviewable specs -- not verbose markdown.

3. **Workflow flexibility is essential**: A one-size-fits-all spec process (like Kiro's) doesn't work. The plugin should scale its output to the size of the task.

4. **The MDD parallel is a strategic risk**: The plugin should explicitly avoid the MDD trap by keeping specs lightweight and disposable rather than trying to make them the "source of truth."

5. **Spec-first (not spec-as-source) is the pragmatic approach**: Generate specs to guide implementation, then let the code be the source of truth. Don't try to maintain spec-code synchronization.

6. **Agent non-compliance with specs is a real problem** that the plugin must acknowledge. Specs improve outcomes but don't guarantee them.

## Criticism of This Source

- The evaluation is based on relatively small projects and toy examples. SDD might perform better at larger scale where the upfront investment pays off.
- The MDD comparison, while instructive, isn't perfect -- LLM-driven code generation is fundamentally different from template-based MDD generation.
- The author has a clear preference for lightweight, pragmatic approaches, which may bias against more structured tools that benefit different team dynamics.
