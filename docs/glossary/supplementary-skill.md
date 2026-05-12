# Supplementary Skill

**Definition:** A document in the exact same format as a skill (with frontmatter and `SKILL.md` body), referenced by other skills or drilldown skills, that should be executed the same way as a skill (loaded via `Skill(...)`).

**Distinction from a regular skill:** Supplementary skills are typically not surfaced to the agent's auto-listing of available skills — they're invoked from a parent (drilldown) skill rather than directly. The visibility mechanism (frontmatter toggle vs. directory placement) is documented separately — see the relevant research note.

**Example:** `message-formatting-discord` is a supplementary skill that the `message-formatting` drilldown skill points to. The agent doesn't directly choose `message-formatting-discord` — it invokes the drilldown, which then routes to the right supplementary based on input.

**See also:** Drilldown Skill, Supplementary Documentation.
