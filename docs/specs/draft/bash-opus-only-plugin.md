# bash-opus-only Plugin

## Overview

A Claude Code plugin that restricts the Bash tool to Opus-class agents only. Sonnet and Haiku agents that attempt to call Bash receive a deny with a helpful error message directing them to use the Task tool to spawn an Opus sub-agent instead.

**Research basis**: `docs/research/bash-opus-only-plugin-feasibility.md` (Road Runner, 2026-02-24)

---

## Problem Statement

In multi-agent teams, Bash access enables arbitrary shell execution. Sonnet and Haiku agents should not run arbitrary shell commands — they should delegate shell work to Opus sub-agents via the Task tool, which provides appropriate sandboxing and oversight.

Today this is enforced per-agent via `disallowed_tools` in agent frontmatter, but:

1. **No universal policy** — a newly added agent can forget `disallowed_tools: [Bash]` and silently get Bash access
2. **No helpful error message** — `disallowed_tools` denies the tool call without telling the agent what to do instead
3. **Maintenance burden** — the restriction must be manually added and maintained in every non-Opus agent definition

A plugin provides a universal safety net with a helpful deny message, without requiring per-agent configuration.

---

## Solution

### Recommended Approach: Hybrid (Frontmatter + Plugin Safety Net)

Per the feasibility research, Approach 3 (hybrid) provides the best coverage:

1. **Primary enforcement**: `disallowed_tools: [Bash]` in non-Opus agent frontmatter (already in place for several agents)
2. **Safety net**: Plugin's PreToolUse hook catches any agent that reaches Bash (e.g., a new agent that forgot `disallowed_tools`)

The plugin acts as a defense-in-depth layer, not a replacement for per-agent frontmatter.

### Model Detection Constraint

The current model is **not detectable from within a hook** — no `CLAUDE_MODEL` env var exists and hook input JSON does not include model information. The plugin therefore relies on a `CLAUDE_AGENT_MODEL` environment variable that must be set by the agent launcher before spawning each agent.

If `CLAUDE_AGENT_MODEL` is not set, the hook defaults to **allow** (safe default — assumes Opus if unknown).

---

## Technical Design

### Plugin Structure

```
plugins/bash-opus-only/
├── .claude-plugin/
│   └── plugin.json
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       └── check-bash-model.sh
└── README.md
```

### hooks.json

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/check-bash-model.sh"
          }
        ]
      }
    ]
  }
}
```

The `matcher: "Bash"` ensures the hook only fires on Bash calls (no overhead for other tools).

### check-bash-model.sh

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../../lib/pretooluse.sh"

# Read model from environment (must be set by agent launcher)
# Defaults to "opus" if unset — safe default (allows Bash when model is unknown)
MODEL="${CLAUDE_AGENT_MODEL:-opus}"

# Allow Opus-class agents
if [[ "$MODEL" == *"opus"* ]]; then
    allow
fi

# Deny non-Opus with helpful message
deny "Bash tool is restricted to Opus-class agents. Use the Task tool to delegate shell work to an Opus sub-agent: Task(subagent_type='Bash', prompt='your command here')"
```

### Error Message Copy

When a non-Opus agent attempts Bash, the deny message shown to Claude is:

> Bash tool is restricted to Opus-class agents. Use the Task tool to delegate shell work to an Opus sub-agent: `Task(subagent_type='Bash', prompt='your command here')`

This message:
- States the restriction clearly
- Provides the correct alternative (Task tool with Bash subagent_type)
- Gives an actionable example

### Launcher Integration

The agent launcher must set `CLAUDE_AGENT_MODEL` before spawning each agent. Example:

```bash
# When spawning a Sonnet agent
export CLAUDE_AGENT_MODEL="claude-sonnet-4-6"
claude --model claude-sonnet-4-6 ...

# When spawning an Opus agent
export CLAUDE_AGENT_MODEL="claude-opus-4-6"
claude --model claude-opus-4-6 ...
```

Without launcher integration, `CLAUDE_AGENT_MODEL` is unset and the hook defaults to `allow` (Opus behavior).

---

## Edge Cases

### Plan Mode

In plan mode (`permission_mode: plan`), Claude Code already blocks Bash natively. The PreToolUse hook may not fire for tools already blocked by plan mode (the tool call is rejected before reaching the hook). No plugin intervention needed for plan mode agents.

### Undetectable Model (No Env Var)

If `CLAUDE_AGENT_MODEL` is not set, the hook allows Bash (defaults to Opus behavior). This is intentional — the plugin should not block legitimate Opus work if the launcher hasn't been updated yet. The per-agent `disallowed_tools` frontmatter remains the primary enforcement layer.

### Opus-Class Model Aliases

The check uses `*opus*` substring matching (`[[ "$MODEL" == *"opus"* ]]`), which covers:
- `claude-opus-4-6`
- `claude-opus-4-5`
- Any future Opus model ID containing "opus"

This will not match `claude-sonnet-4-6`, `claude-haiku-4-5`, or non-Claude models.

### Future Model Names

If Anthropic releases an Opus-equivalent model not named "opus" (e.g., a code-specific Opus variant), the allow list will need updating. The env var approach makes this easy — update the launcher's env var value, not the plugin logic.

### Hook Interaction with disallowed_tools

If the agent's frontmatter includes `disallowed_tools: [Bash]`, the tool call may be rejected before the hook fires. In this case the plugin's deny message is not shown — the native Claude Code denial applies. This is acceptable: the primary enforcement (frontmatter) works correctly, and the plugin safety net only fires for agents that lack frontmatter enforcement.

---

## Out of Scope

- Restricting tools other than Bash (separate concern)
- Per-tool restrictions within Bash (e.g., blocking only certain commands)
- Automatic model detection without launcher integration
- Backfilling `disallowed_tools` to all existing agent files (separate task)

---

## Implementation Notes

- **Hook type**: `PreToolUse` — fires before the tool call, can deny with a message
- **Matcher**: `"Bash"` — efficient, only fires for Bash
- **Dependencies**: `pretooluse.sh` helper from `ai-mktpl/.claude/hooks/lib/`
- **Launcher requirement**: `CLAUDE_AGENT_MODEL` env var must be set at agent spawn time
- **Open question from research**: Whether `disallowed_tools` frontmatter prevents the hook from firing at all (if so, the safety net is narrower than designed — only catches agents missing frontmatter enforcement)

---

## Open Questions

1. **Does `disallowed_tools` frontmatter prevent the PreToolUse hook from firing?** If yes, the hybrid approach's safety net only catches agents that forget frontmatter — which is still valuable, but different from a universal blocker.
2. **Should the plugin also write a PostToolUse hook to log Bash usage?** Audit logging for all Bash calls (agent name, command, outcome) could be valuable for security review.
3. **Launcher integration timeline**: The plugin is only effective if `CLAUDE_AGENT_MODEL` is set. Should the plugin emit a warning (not a deny) if the env var is missing, to alert the operator?

---

## References

- [Road Runner's Feasibility Research](../research/bash-opus-only-plugin-feasibility.md)
- [Claude Code Hooks Docs](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [Claude Code Plugins Docs](https://code.claude.com/docs/en/plugins)
- [Agent Teams Docs](https://code.claude.com/docs/en/agent-teams)
- Related research: `agent-team/docs/research/tool-stripping.md`
