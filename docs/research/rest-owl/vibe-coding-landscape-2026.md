# Vibe Coding: The Landscape in 2026

**Sources**:

- https://cloud.google.com/discover/what-is-vibe-coding (Google Cloud)
- https://en.wikipedia.org/wiki/Vibe_coding (Wikipedia)
- https://designrevision.com/blog/vibe-coding (DesignRevision)
  **Date read**: 2026-03-20

## Key Takeaways

- Term coined by Andrej Karpathy in Feb 2025: "fully give in to the vibes"
- Collins Dictionary Word of the Year 2025
- Vibe coding = accepting AI-generated code without reviewing it, relying on results
- By 2026: 92% of US developers use AI coding tools daily, 41% of all code is AI-generated
- Evolution: Karpathy coined "agentic engineering" in Feb 2026 — structured oversight of autonomous AI agents
- **The 80/20 problem**: Vibe coding produces first 80% in hours, last 20% (production-readiness) still needs deep understanding

## Risks Documented

- 45% of AI-generated code fails security tests (Veracode 2025)
- AI code has 1.7x more "major" issues, 2.74x higher security vulnerabilities (CodeRabbit)
- $1.5 trillion predicted technical debt by 2027 from poorly structured AI code
- Only 16.3% of developers said AI made them "more productive to a great extent" (Stack Overflow 2025)

## Relevance to rest-owl Plugin

Our plugin is explicitly positioned in the gap between vibe coding and spec-driven development:

1. **We bridge the 80/20** — Vibe coding gets you started fast but falls apart at scale. Our spec-first approach (research → spec → design → build) ensures the foundation is solid.
2. **Security by design** — The 45% security failure rate validates our Phase 6 validation pipeline. Testing isn't optional.
3. **Agentic engineering alignment** — Karpathy's "agentic engineering" (structured oversight of AI agents) is exactly what our orchestrator skill does — it's a structured workflow where the AI is supervised at checkpoints.
4. **The credibility problem** — Only 16.3% of developers find AI highly productive. Our plugin needs to demonstrate value through rigor, not just speed.

## Design Implication

Position the plugin explicitly as "not vibe coding" — it's the rigorous alternative that still leverages AI's speed. The spec artifacts serve as proof of work and accountability that pure vibe coding lacks.
