# Vibe Coding: AI-First Development and the Idea-to-Implementation Gap

## Sources
- **Wikipedia**: https://en.wikipedia.org/wiki/Vibe_coding
- **Google Cloud**: https://cloud.google.com/discover/what-is-vibe-coding
- **Kristin Darrow - State of Vibecoding Feb 2026**: https://www.kristindarrow.com/insights/the-state-of-vibecoding-in-feb-2026
- **Volumetree**: https://www.volumetree.com/2026/03/05/vibe-coding-pros-cons-2026/
- **SitePoint Guide 2026**: https://www.sitepoint.com/vibe-coding-2026-complete-guide/

## What Is Vibe Coding?

Coined by Andrej Karpathy (OpenAI co-founder, former Tesla AI lead) in February 2025. Named Collins English Dictionary Word of the Year 2025. The concept: rely on LLMs to generate working code from natural language descriptions rather than manually writing or reviewing it.

## Evolution from 2025 to 2026

What started as "prompt an LLM and just vibe with whatever comes back" has matured into a structured AI-first development methodology with:
- Multi-model orchestration
- Persistent project context
- Layered validation
- Structured human oversight

## Key Stats

- Y Combinator Winter 2025: 25% of startups had codebases 95% AI-generated
- 92% of US developers use AI coding tools daily
- iOS app releases increased ~60% YoY in late 2025

## The Gap Problem

The defining tension of 2026: **whether improved AI coding models can close the gap between software that works (easy to demo) and software that is secure, maintainable, and reliable.**

This is essentially the "rest of the owl" problem applied to software:
- Step 1: Describe what you want
- Step 2: Get working software
- Missing middle: security, scalability, reliability, maintainability

## Risks and Evidence

- METR trial (July 2025): experienced developers were **19% slower** with AI tools despite predicting they'd be 24% faster
- ~45% of AI-generated code introduced OWASP vulnerabilities
- AI co-authored PRs had 1.7x more "major" issues (CodeRabbit, Dec 2025)
- 40%+ junior devs deployed AI code they didn't fully understand (Deloitte 2025)

## The Experience Gap

The gap between a vibe coder with no engineering background and one with 15 years of experience is enormous. Engineering experience lets you recognize when AI-generated code is subtly wrong.

## Top Tools (2026)

Cursor, Replit Agent, Lovable, Bolt.new, Forge, Claude Code, Google Gemini

## Relevance to Plugin Development

1. **Vibe coding IS the "draw two circles" step** -- it gives you the start and the end but skips the engineering middle.
2. **A plugin that generates specs/scaffolding addresses the identified gap** between "works as demo" and "production-ready."
3. **The maturation of vibe coding toward structured specs** validates the spec-driven approach.
4. **Experience gap is the key differentiator** -- a plugin that embeds senior engineering knowledge into the scaffolding process could level the playing field.

## Criticism

- Vibe coding evangelists may overstate its maturity. The stats on vulnerability rates and speed reductions suggest the tooling isn't as ready as marketing implies.
- The term itself is vague and has become a buzzword applied to many different workflows.
- Risk of deskilling: if developers rely on AI for the "middle," they may never develop the judgment to evaluate AI output.
