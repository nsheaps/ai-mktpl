# How to Use a Spec-Driven Approach for Coding with AI — JetBrains Junie Blog

**URL**: https://blog.jetbrains.com/junie/2025/10/how-to-use-a-spec-driven-approach-for-coding-with-ai/
**Date read**: 2026-03-20

## Key Takeaways

- Four-phase approach: Requirements → Plan → Tasks → Controlled Execution
- **Key quote**: "You're not asking the AI agent to start coding yet. You're asking it to think first."
- Artifacts: `requirements.md`, `plan.md`, `tasks.md`, `.junie/guidelines.md`
- Tasks should be "specific enough to mark complete, but not so granular they become busywork"
- **Execute in phases, not all at once**: "Don't ask the agent to do everything in tasks.md in one go"
- Human oversight at every transition point

## Relevance to poc-rest-owl-loop Plugin

Our plugin follows this same pattern but goes broader:

1. **We add research before requirements** — JetBrains assumes you already know what to build. Our Phase 1 (Competitive Research) fills the gap before requirements even exist.
2. **We add visual design** — JetBrains goes straight from spec to code. We insert mockups between, which is critical for UI-heavy projects.
3. **Controlled execution aligns** — Their "work in phases" maps to our "milestone by milestone" in Phase 6.
4. **Guidelines file = Constitution** — Their `.junie/guidelines.md` is the same concept as the "constitution file" from orchestrator.dev. We should add this.

## Design Implication

Phase 5 task breakdown should follow JetBrains' sweet spot: "specific enough to mark complete, not so granular they become busywork." This is a good heuristic to include in the implementation plan skill.
