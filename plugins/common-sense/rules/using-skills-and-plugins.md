# Using Skills and Plugins

- You have a vast array of plugins and skills which configure your behavior and capabilities.
  - Plugins are a powerful encapsulation mechanism (https://code.claude.com/docs/en/plugins) for shared logic around a purpose for configuring Claude Code and should be considered industry standard best practice for sharing everything except rules (but if possible we should consider a mechanism for it, so don't rule it out even if the support isn't there yet) and settings.json.
  - Skills are a now-industry-standard (https://agentskills.io) way of encapsulating logic for specific tasks.
- Whenever possible you SHOULD try to encapsulate requested behavior changes in a plugin or skill
- When making changes to Claude Code configuration files, always use the `/configuring-claude-code` skill and `claude-code-guide` agent.
- For all other tasks, you MUST prefer to try to utilize an existing skill or plugin to accomplish the user's request.
- ALWAYS try to update skills and plugins (using a run_in_background Task) to improve their behavior:
  - when you notice gaps or errors in their behavior during your normal use
  - when you notice that they could be improved to better suit your needs
  - ...especially if they seem to be created by the same organization you work for
  - ...or if the goal is to create reusable components for claude code, claude agent sdk, internal users, or external customers.

## Skill-First Enforcement (CRITICAL)

**Before starting ANY work on a task, you MUST invoke all relevant skills via the Skill tool.** Skills are the single source of truth for how to do recurring operations — format, destination, data sources, pitfalls.

### The rule

1. **Before taking action**, identify which skills are relevant to the task.
2. **Invoke each relevant skill** via the Skill tool to load its current content into context. Do this even if you "remember" the skill — the content may have changed since your last read.
3. **Only then** start the work, following the skill's instructions.
4. **If the skill disagrees with other sources** (yaml, rules, memory), the skill wins. Update the other sources to match after finishing the work.
5. **If delegating to a sub-agent**, the sub-agent MUST also follow this rule — include explicit instructions in the prompt to read the relevant skill first, and link to its path.

If no skill matches and the work is non-trivial or recurring, **create a new skill capturing what you learn** as you do it.

### Anti-patterns

| Pattern | Problem |
|---------|---------|
| Acting on a cron/scheduled prompt without checking its skill first | Stale config in the prompt may differ from the skill's current instructions |
| Delegating to a sub-agent without telling it to read the relevant skill | Sub-agent will use defaults or stale context instead of the skill's instructions |
| Using a tool (Discord API, GitHub API, etc.) from memory without checking its skill | Miss post-action checklists, formatting requirements, or destination changes |
| Skipping skill recall because "I just read it recently" | Skill content may have been updated since your last read |
