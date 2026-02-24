# Agent Representation with Exclusive Plugins

**Status**: Draft
**Author**: Bugs Bunny (Software Eng)
**Date**: 2026-02-17

---

## 1. Problem Statement

Agent roles (orchestrator, software-eng, QA, etc.) are currently defined as standalone `.claude/agents/*.md` files with embedded system prompts, tool lists, and behavioral instructions. There's no mechanism to give different agents different **plugins** — all agents in a repo share the same `enabledPlugins` from `settings.json`.

This means:

- A QA agent gets the same commit command as the software engineer
- An orchestrator that should never write code still has access to code-related skills
- Behavioral plugins (context-bloat-prevention, safety-evaluation) can't be selectively applied per role
- Adding a new plugin affects ALL agents, even ones it's irrelevant to

## 2. Current State

### Agent Definition Format (agent-team repo)

```yaml
---
name: software-eng
description: |
  Primary implementation agent...
color: green
prompt_mode: extend
base_prompt: _builtin
framework: claude-code
model: claude-opus-4-6
permission_mode: delegate
display_name: "Bugs B (software-eng)"
tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
disallowed_tools:
  - ...
---
```

**What's controlled per-agent today**: name, description, color, tools, disallowed_tools, model, permission_mode, display_name, prompt_mode, and the body (system prompt + behavioral instructions).

**What's NOT controlled per-agent today**: plugins, hooks, settings, MCP servers.

### Plugin Structure (nsheaps/ai repo)

27 plugins in `nsheaps/ai/plugins/`, each containing some combination of:

- `.claude-plugin/plugin.json` — manifest (name, version, description, keywords)
- `commands/` — slash commands
- `skills/` — SKILL.md files
- `hooks/` — event hooks
- `agents/` — agent definitions
- `README.md`

### Gap

No way to say "agent X uses plugins A, B, C" while "agent Y uses plugins D, E, F."

## 3. Design: Per-Agent Plugin Sets

### 3.1 Concept: Plugin Profiles

A **plugin profile** is a named set of plugins appropriate for a specific agent role. Profiles are defined in a configuration file and referenced by agent definitions.

Plugin profiles are **project-specific** — each repo defines its own `.claude/plugin-profiles.yaml` based on its team composition and installed plugins. Marketplace repos (like nsheaps/ai) may ship default profiles as templates, but consuming projects override them locally.

```yaml
# .claude/plugin-profiles.yaml (project-specific, not distributed)

profiles:
  orchestrator:
    description: "Coordination and task management only"
    plugins:
      - context-bloat-prevention
      - task-parallelization
      - safety-evaluation-prompt
    exclude:
      - scm-utils
      - commit-command

  software-eng:
    description: "Full implementation toolkit"
    plugins:
      - scm-utils
      - commit-command
      - code-simplifier
      - context-bloat-prevention
      - safety-evaluation-prompt

  quality-assurance:
    description: "Review and testing focus"
    plugins:
      - review-changes
      - safety-evaluation-prompt
      - context-bloat-prevention
    exclude:
      - commit-command

  docs-writer:
    description: "Documentation and spec maintenance"
    plugins:
      - scm-utils
      - context-bloat-prevention
      - product-development-and-sdlc

  researcher:
    description: "Deep research with web access"
    plugins:
      - context-bloat-prevention

  ops-eng:
    description: "Build tooling and release management"
    plugins:
      - scm-utils
      - commit-command
      - context-bloat-prevention
      - git-spice

  ai-agent-eng:
    description: "Process observation and coaching"
    plugins:
      - context-bloat-prevention
      - safety-evaluation-prompt
      - correct-behavior
      - commit-command # needed for /correct-behavior which commits fixes directly

  project-manager:
    description: "Task management, no implementation"
    plugins:
      - context-bloat-prevention
      - product-development-and-sdlc
    exclude:
      - scm-utils
      - commit-command
      - code-simplifier
```

### 3.2 Agent File Reference

Agent files reference their profile:

```yaml
---
name: software-eng
plugin_profile: software-eng
# ... other frontmatter
---
```

### 3.3 Inheritance Model

```
Global enabledPlugins (settings.json)
  └── Plugin Profile (per-agent override)
       ├── plugins: [...] — additions specific to this role
       └── exclude: [...] — removals from global set
```

**Resolution**: `effective_plugins = (global_plugins + profile.plugins) - profile.exclude`

### 3.4 Shared vs Exclusive Plugins

| Plugin                         | All Agents                                                                    | Specific Roles                     |
| :----------------------------- | :---------------------------------------------------------------------------- | :--------------------------------- |
| `context-bloat-prevention`     | Yes (but role-specific thresholds — researchers need larger context than PMs) | —                                  |
| `safety-evaluation-prompt`     | Yes                                                                           | —                                  |
| `scm-utils`                    | —                                                                             | software-eng, ops-eng, docs-writer |
| `commit-command`               | —                                                                             | software-eng, ops-eng              |
| `code-simplifier`              | —                                                                             | software-eng                       |
| `review-changes`               | —                                                                             | quality-assurance                  |
| `product-development-and-sdlc` | —                                                                             | project-manager, docs-writer       |
| `correct-behavior`             | —                                                                             | ai-agent-eng                       |
| `git-spice`                    | —                                                                             | ops-eng                            |
| `task-parallelization`         | —                                                                             | orchestrator                       |

## 4. Implementation Approaches

### Approach A: Convention-Based (No Claude Code Changes)

Since Claude Code doesn't currently support per-agent plugin selection, this approach uses **agent file body instructions** to simulate exclusive plugins.

Each agent's body includes instructions like:

```markdown
## Available Skills

You have access to these skills and should use them:

- /commit (scm-utils) — for committing changes
- /update-branch (scm-utils) — for syncing branches

## Unavailable Skills

Do NOT use these skills — they are not part of your role:

- /review-changes — this is the QA agent's responsibility
```

**Pros**: Works today, no platform changes needed
**Cons**: Soft enforcement only — agent can still technically use any installed skill

> **Compaction risk**: Body text instructions are vulnerable to loss during context compaction (see team Failures #4, #9). To mitigate:
>
> - Place skill restrictions in the `<system-message>` block (survives compaction)
> - Or reference an external file (e.g., `@.claude/plugin-profiles.yaml`) that the agent re-reads after compaction
> - Make refusal instructions extremely explicit: "You MUST refuse to use /commit. It is not part of your role. Redirect the requester to the software-eng agent."
> - Do NOT rely on body text alone for critical restrictions

### Approach B: Launcher-Mediated (claude-team Enhancement)

The `claude-team` launcher script generates per-agent `--settings` overrides that control `enabledPlugins`:

```bash
# In claude-team or agent spawn logic
AGENT_SETTINGS=$(generate_agent_settings "$AGENT_ROLE")
claude --settings "$AGENT_SETTINGS" ...
```

**Pros**: Hard enforcement at launch time, uses existing `--settings` flag
**Cons**: Only works for the lead agent launched by claude-team; teammates spawned by Claude Code itself can't be controlled this way (spawn not customizable per Road Runner's research)

### Approach C: Plugin Profile as Plugin (Meta-Plugin)

Create a plugin that reads `.claude/plugin-profiles.yaml` and uses hooks to enforce plugin boundaries:

```json
{
  "name": "plugin-profiles",
  "hooks": {
    "PreToolUse": [
      {
        "type": "prompt",
        "prompt": "Check if the current agent's role allows use of this tool/skill..."
      }
    ]
  }
}
```

**Pros**: Enforced at runtime, works for all agents including teammates
**Cons**: Hooks fire on every tool use (performance), relies on prompt-based enforcement (soft)

### Approach D: Claude Code Native (Future)

Request Claude Code support for per-agent `enabledPlugins` in the agent frontmatter:

```yaml
---
name: software-eng
enabledPlugins:
  - scm-utils
  - commit-command
  - code-simplifier
---
```

**Pros**: Hard enforcement, clean API, no workarounds
**Cons**: Requires Claude Code platform changes

### Recommended Phased Approach

| Phase     | Approach                                              | When                                              |
| :-------- | :---------------------------------------------------- | :------------------------------------------------ |
| **Now**   | A (convention-based)                                  | Immediate — add skill guidance to agent files     |
| **Soon**  | B (launcher for lead) + C (meta-plugin for teammates) | When agent-team launcher is built                 |
| **Later** | D (native support)                                    | When/if Claude Code adds per-agent plugin control |

## 5. Role-to-Plugin Mapping (Full)

Based on the 8 roles defined in `.claude/agents/` and the 27 plugins in `nsheaps/ai/plugins/`:

| Role                  | Must Have                                                            | Nice to Have                                                       | Must NOT Have                              |
| :-------------------- | :------------------------------------------------------------------- | :----------------------------------------------------------------- | :----------------------------------------- |
| **orchestrator**      | context-bloat-prevention, task-parallelization                       | safety-evaluation-prompt                                           | scm-utils, commit-command, code-simplifier |
| **software-eng**      | scm-utils, commit-command, context-bloat-prevention                  | code-simplifier, git-spice                                         | —                                          |
| **quality-assurance** | review-changes, context-bloat-prevention                             | safety-evaluation-prompt                                           | commit-command                             |
| **docs-writer**       | scm-utils, context-bloat-prevention, product-development-and-sdlc    | skills-maintenance                                                 | —                                          |
| **deep-researcher**   | context-bloat-prevention                                             | —                                                                  | scm-utils, commit-command                  |
| **ops-eng**           | scm-utils, commit-command, git-spice, context-bloat-prevention       | statusline-iterm                                                   | —                                          |
| **ai-agent-eng**      | correct-behavior, context-bloat-prevention, safety-evaluation-prompt | skills-maintenance, commit-command (for /correct-behavior commits) | —                                          |
| **project-manager**   | context-bloat-prevention, product-development-and-sdlc               | todo-sync                                                          | scm-utils, commit-command                  |

## 6. Open Questions

1. **Teammate plugin control**: Teammates are spawned by Claude Code directly. Can `--settings` be passed per-teammate, or is it only for the lead session? (Road Runner's research says spawn is not customizable.)

2. ~~**Plugin profile inheritance**: Should profiles support `extends`?~~ **Answer: No, not yet.** YAGNI — flat profiles are simpler to reason about and sufficient for 8 roles. Revisit if profile count exceeds ~15 and duplication becomes painful.

3. **Dynamic profiles**: Should profiles be selectable at runtime? e.g., "switch this agent to review mode" changes its plugin set mid-session.

4. **MCP server plugins**: Some plugins provide MCP servers. Should MCP server availability also be controlled per-agent?

5. **Cross-repo profiles**: If profiles live in the agent-team repo but plugins live in nsheaps/ai, how does the profile reference resolve? By plugin name across marketplaces?

6. **Convention enforcement**: For Approach A, how strictly should we enforce? Should agents be instructed to refuse if asked to use an excluded skill, or just "prefer not to"?

7. **Delegate mode interaction**: The delegate mode bug ([#25037](https://github.com/anthropics/claude-code/issues/25037)) causes teammates to inherit delegate restrictions incorrectly. This may interact with plugin profile enforcement if Approach B or C relies on permission boundaries. Monitor the bug resolution before implementing hard enforcement.

## 7. Next Steps

1. Start with Approach A: Add "Available/Unavailable Skills" sections to each agent file in `.claude/agents/`
2. Create `.claude/plugin-profiles.yaml` as the source of truth for role-to-plugin mapping
3. Test whether the convention-based approach is sufficient for team coordination
4. File a feature request for Claude Code native per-agent plugin support if needed

## References

- Agent definitions: `nsheaps/agent-team/.claude/agents/*.md` (8 files)
- Plugin marketplace: `nsheaps/ai/plugins/` (27 plugins)
- Marketplace structure spec: `nsheaps/agent-team/docs/specs/draft/marketplace-structure.md`
- Persona system spec: `nsheaps/agent-team/docs/specs/draft/persona-system.md`
- Road Runner's spawn research: `nsheaps/claude-utils/.claude/tmp/teammate-launch-research.md`
- [Claude Code Plugins](https://code.claude.com/docs/en/plugins)
- [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams)
- [Claude Code Sub-Agents](https://code.claude.com/docs/en/sub-agents)
