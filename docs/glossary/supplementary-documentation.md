# Supplementary Documentation

**Definition:** A document referenced by a skill (or by another doc) but NOT `@`-referenced (i.e. not auto-loaded). The agent CHOOSES whether to read the additional info based on whether the current task requires it.

**Distinction from regular documentation:** Regular docs that are `@`-referenced get pulled into context automatically. Supplementary documentation requires an explicit `Read` action by the agent — costs more time but doesn't bloat context for tasks that don't need it.

**When to use:** For deep-dive references, edge-case workarounds, troubleshooting guides, or other content that's only relevant to a subset of the agent's work and would otherwise consume context unproductively.

**See also:** Drilldown Skill, Supplementary Skill.
