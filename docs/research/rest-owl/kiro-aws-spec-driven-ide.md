# Kiro (AWS): Spec-Driven Agentic IDE

## Sources

- **InfoQ - Beyond Vibe Coding**: https://www.infoq.com/news/2025/08/aws-kiro-spec-driven-agent/
- **The New Stack - Testing Kiro**: https://thenewstack.io/aws-kiro-testing-an-ai-ide-with-a-spec-driven-approach/
- **DEV Community - What I Learned Using SDD with Kiro**: https://dev.to/aws-builders/what-i-learned-using-specification-driven-development-with-kiro-pdj
- **HarrisonAIX Review**: https://harrisonaix.com/kiro-review/
- **Kear AI - One Month Testing Kiro**: https://kearai.com/agents/kiro-ai-review-aws-agentic-ide-guide
- **Kiro Official**: https://kiro.dev/

## What Is Kiro?

AI-powered IDE by AWS, built on Code OSS (VS Code foundation), powered by Claude Sonnet (Anthropic). Currently early access, attracting 1M+ monthly visitors.

## Core Differentiator

Most AI coding tools (Cursor, Bolt, Lovable) take a rough idea and generate code immediately. Kiro operates at the **specification layer first**. Before writing a single line of code, Kiro helps formalize intent into a structured spec, then uses that spec to generate code "provably aligned with your intent."

## Three-Phase Workflow

1. **Requirements (EARS notation)**: Define behavior formally ("WHEN X THEN Y")
2. **Design**: Generate architecture docs, diagrams, schemas
3. **Tasks**: Only then create implementation tasks

This prevents "spaghetti code generation" from free-wheeling chat agents.

## User Experience Reports

### Positive

- "Spent more time upfront articulating what I wanted to build, but then could step back and let it execute"
- "The difference between being a hands-on manager versus setting clear expectations and trusting the process"
- "Kiro did not invent good engineering practices. It made them unavoidable."
- "It taught users how to think before writing code. That turns out to be the hardest and most valuable part of engineering."
- Teams report "reducing time to customer value from weeks to days"

### Negative

- 50 interactions/month on free tier runs out fast
- Spec overhead is friction for simple tasks
- Learning curve for EARS notation and formal spec writing
- Less suitable for "hacky" prototyping or rapid exploration
- "Occasionally drive me absolutely mad with its learning curve"

## Positioning

- **Kiro**: Best for complex features needing upfront design clarity. Ideal for senior engineers and architects who value correctness over speed.
- **Cursor**: Best for fast iteration and rapid prototyping.
- **Key question Kiro asks**: "What if AI could help you plan before you code?" (vs. competitors who help you code faster)

## Notable Incident

An engineer's Kiro-generated AWS integration code triggered an unintended cascade causing a localized AWS service disruption. "Vibe too hard, brought down AWS" became a developer meme. This illustrates that even spec-driven approaches don't guarantee safe outputs.

## Relevance to Plugin Development

1. **Kiro validates the spec-first approach commercially** -- AWS is investing heavily in this direction. 1M+ monthly visitors shows demand.

2. **The EARS notation is a specific, learnable framework** for requirements. A plugin could adopt or simplify this (WHEN/THEN patterns are intuitive).

3. **The "made good practices unavoidable" insight is the key value proposition** -- a plugin should make it harder to skip important steps than to include them.

4. **Kiro's weakness (overhead for simple tasks) is a design lesson**: A plugin must scale its formality to task complexity. Don't generate 4 user stories for a bug fix.

5. **Kiro is a competitor, not just a reference**: Any plugin in this space competes with Kiro. Differentiation would need to come from lighter weight, better Claude Code integration, or different scope.

6. **The "think before you code" framing resonates** -- this is essentially "draw the rest of the owl" rephrased for developers.

## Criticism

- Kiro's tight coupling to AWS ecosystem may limit its appeal to non-AWS shops.
- EARS notation adds formalism that many developers will resist.
- The "weeks to days" claim is marketing; no independent verification.
- The AWS service disruption incident undermines the "provably aligned with intent" claim.
- Early access means the product may change significantly. Research may become outdated quickly.
