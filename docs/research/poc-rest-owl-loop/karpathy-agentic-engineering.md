# Agentic Engineering — Andrej Karpathy (Feb 2026)

**Sources**:

- https://addyosmani.com/blog/agentic-engineering/ (Addy Osmani's comprehensive summary)
- https://www.ibm.com/think/topics/agentic-engineering (IBM)
- https://www.glideapps.com/blog/what-is-agentic-engineering (Glide)
- https://www.nxcode.io/resources/news/agentic-engineering-complete-guide-vibe-coding-ai-agents-2026 (NxCode)
  **Date read**: 2026-03-20

## Key Takeaways

- Coined Feb 8, 2026 by Karpathy as the professional successor to vibe coding
- **Definition**: "You are not writing the code directly 99% of the time. You are orchestrating agents who do and acting as oversight."
- **Biggest distinction from vibe coding**: Testing. "With a strong test suite, AI agents can iterate until tests pass. Without tests, an agent may incorrectly declare a task complete."
- Developer's new role: trading typing time for review time, implementation effort for orchestration skill
- **Better specs → better AI output. Better tests → more confident delegation. Cleaner architecture → less hallucination.**
- Planning phase is where engineering expertise matters most — vague plans produce vague code
- Agents iterate autonomously within defined constraints; humans intervene for judgment calls

## Market Data

- 84% of developers use or intend to use AI-assisted programming (Stack Overflow 2025)
- Stripe's AI agents produce 1,000+ merged PRs per week
- $4.7B market projected to $12.3B by 2027
- Gartner: 40% of enterprise apps will have AI agents by end of 2026

## Relevance to poc-rest-owl-loop Plugin

**Our plugin IS agentic engineering applied to project creation.** Key alignment:

1. **Orchestration, not implementation** — The orchestrator skill coordinates sub-skills (research, spec, design, validation). The human provides oversight through checkpoints.
2. **Testing as the foundation** — Karpathy's emphasis on testing validates our Phase 6. Testing isn't an afterthought; it's what makes the whole agentic workflow reliable.
3. **Planning is the hard part** — Our Phases 0-5 ARE the planning. Phase 6 (build) is actually the "easy" part once specs and tests are defined.
4. **Better specs → better output** — Our Phase 2 quality directly determines Phase 6 quality. This is now validated by industry consensus.

## Design Implication

The plugin should explicitly position itself as an "agentic engineering workflow" — it's not vibe coding, it's structured orchestration with human oversight. Consider adding this framing to the README and main skill description. Also: emphasize that testing is what makes the whole thing work, not an optional add-on.
