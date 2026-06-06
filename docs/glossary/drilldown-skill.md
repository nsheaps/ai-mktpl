# Drilldown Skill

**Definition:** A basic skill used as an index for finding other skills. Used when you want a skill to be recallable by a generic concept (e.g. "format a message") but execution to be specific by output mechanism (e.g. format-for-discord, format-for-github, format-for-slack each behaving differently).

**Relationship to "Drill-Down Documentation":** Both share the "drill from generic to specific" pattern, but the documentation pattern is for human readers navigating reference docs, while the skill pattern is for agents looking up the right execution path at runtime.

**Structure:**

A drilldown skill's `SKILL.md` typically:

- Has a generic name (e.g. `message-formatting`)
- Lists or auto-discovers child skills (e.g. via `!`bash`` directory listing)
- @-references shared excerpts on how to consume drilldown skills
- Does NOT contain the per-platform/per-mechanism execution details — those live in supplementary skills it points to

**Example:**

```
agentic-behavior/skills/
├── message-formatting/SKILL.md         # drilldown — generic concept
├── message-formatting-discord/SKILL.md # supplementary — Discord-specific
├── message-formatting-github/SKILL.md  # supplementary — GitHub-specific
└── message-formatting-slack/SKILL.md   # supplementary — Slack-specific
```

**See also:** Supplementary Skill, Supplementary Documentation.
