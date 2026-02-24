# Bash Tool Restriction by Model: Plugin Feasibility Research

Research Date: 2026-02-24
Researcher: Road Runner (Deep Researcher)
Task: #230 / #11

## Question

Can a Claude Code plugin restrict the Bash tool to only Opus-model agents, denying it for Sonnet/Haiku with a helpful error message?

## Answer

**Yes, this is feasible through multiple approaches**, with varying levels of complexity. The simplest approach (agent frontmatter `disallowed_tools`) already works today with no plugin needed. A dynamic plugin approach is also feasible but requires a workaround for model detection, since the current model is **not directly available** to hook scripts.

---

## 1. Can Plugins Intercept and Block Tool Calls?

### Yes — PreToolUse hooks

**Confidence: High** — verified from existing implementations in `nsheaps/ai-mktpl`

PreToolUse hooks can intercept any tool call and return `deny` with a custom reason:

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/../lib/pretooluse.sh"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

if [[ "$TOOL_NAME" == "Bash" ]]; then
    deny "Bash is not available for non-Opus agents. Use the Task tool instead — it spawns an Opus sub-agent with Bash access."
fi

allow
```

The deny reason is shown to Claude, which can then adapt its behavior.

### Hook Response Format

```json
{
  "hookSpecificOutput": {
    "permissionDecision": "deny",
    "permissionDecisionReason": "Bash restricted to Opus agents only. Use Task tool to spawn an Opus sub-agent."
  }
}
```

### Existing Examples

- `ai-mktpl/.claude/hooks/pre-tool-use/warn-force-push.sh` — blocks `git push --force`
- `ai-mktpl/plugins/self-terminate/hooks/PreToolUse/validate-git-state.sh` — blocks Bash when running self-terminate with dirty git state
- `ai-mktpl/plugins/context-bloat-prevention/` — redirects large Bash output
- `ai-mktpl/plugins/safety-evaluation-script/` — evaluates tool safety before execution

### Plugin Hook Configuration

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/check-bash-model.sh"
          }
        ]
      }
    ]
  }
}
```

The `matcher` field can target specific tools, so the hook only fires for Bash calls (efficient).

---

## 2. What Plugin Hook Mechanism Supports Tool Restriction?

### PreToolUse Hook (Primary Mechanism)

**Confidence: High**

| Feature | Details |
|---------|---------|
| Hook type | `PreToolUse` |
| Matcher | Tool name pattern (e.g., `"Bash"`) |
| Input | JSON on stdin: `{ "tool_name": "Bash", "tool_input": { "command": "..." } }` |
| Output | JSON on stdout with `permissionDecision`: `allow`, `deny`, or `ask` |
| Deny message | Shown to Claude via `permissionDecisionReason` |
| Exit code | Must be 0 for the response to be processed |

### Agent Frontmatter `disallowed_tools` (Static Alternative)

**Confidence: High** — verified from agent files in `nsheaps/agent-team/.claude/agents/`

Agent frontmatter supports `disallowed_tools`:

```yaml
---
name: orchestrator
model: claude-sonnet-4-6
disallowed_tools:
  - Bash
  - Edit
  - Write
---
```

This is a **static, per-agent** restriction that requires no plugin. Currently used by:
- `orchestrator.md` — disallows Bash, Edit, Write
- `project-manager.md` — disallows Bash, Edit, Write
- `quality-assurance.md` — disallows Edit, Write
- `deep-researcher.md` — disallows Edit, Write
- `designer.md` — disallows Edit, Write

### Tool Permissions in settings.json

Claude Code's `settings.json` has `allowedTools` and `permissions` sections, but these apply globally — not per-model. A plugin can contribute to `settings.json` but cannot conditionally apply settings based on the active model.

---

## 3. Is the Current Model Detectable from Within a Hook?

### Not in PreToolUse — But Available in SessionStart

**Confidence: High** — verified from [Claude Code hooks documentation](https://code.claude.com/docs/en/hooks#sessionstart-input)

**PreToolUse hooks** receive only:
- `tool_name` — the tool being called
- `tool_input` — the tool's parameters (e.g., `command` for Bash)
- Common fields: `session_id`, `cwd`, `permission_mode`, `hook_event_name`

PreToolUse does **NOT** receive: the active model name/ID, the agent type, or session configuration.

**SessionStart hooks** DO receive the `model` field:
```json
{
  "session_id": "abc123",
  "hook_event_name": "SessionStart",
  "model": "claude-sonnet-4-6"
}
```

### Bridging Model Info from SessionStart to PreToolUse

**Approach A: `CLAUDE_ENV_FILE` (Recommended — First-Party Mechanism)**

**Confidence: High** — documented at [Claude Code hooks: Persist environment variables](https://code.claude.com/docs/en/hooks#persist-environment-variables)

SessionStart hooks have access to `CLAUDE_ENV_FILE`, a file path where you can write `export` statements that become available in subsequent Bash commands during the session.

**SessionStart hook** (captures model):
```bash
#!/usr/bin/env bash
INPUT=$(cat)
MODEL=$(echo "$INPUT" | jq -r '.model // empty')
echo "export CLAUDE_AGENT_MODEL=\"$MODEL\"" >> "$CLAUDE_ENV_FILE"
```

**PreToolUse hook** (reads model and blocks Bash):
```bash
#!/usr/bin/env bash
source "$CLAUDE_ENV_FILE" 2>/dev/null || true
if [[ "$TOOL_NAME" == "Bash" && "$CLAUDE_AGENT_MODEL" != *"opus"* ]]; then
    deny "Bash restricted to Opus. Use Task tool to spawn an Opus sub-agent."
fi
```

**Note**: `CLAUDE_ENV_FILE` is documented for Bash commands. Whether the exported variables are also available to PreToolUse hook scripts needs empirical verification — if not, the hook can `source` the env file directly.

**Approach B: Custom Environment Variable via Launcher**

Set a model indicator in `settings.json` or via the agent launcher:

```json
// settings.json (env section)
{
  "env": {
    "CLAUDE_AGENT_MODEL": "opus"
  }
}
```

Or in agent launcher, export before spawning:
```bash
export CLAUDE_AGENT_MODEL="sonnet"
claude --model claude-sonnet-4-6 ...
```

Then in the PreToolUse hook:
```bash
MODEL="${CLAUDE_AGENT_MODEL:-opus}"
if [[ "$TOOL_NAME" == "Bash" && "$MODEL" != "opus" ]]; then
    deny "Bash restricted to Opus. Use Task tool to spawn an Opus sub-agent."
fi
```

**Approach C: Read Agent Frontmatter (File-Based)**

If the agent name is knowable (e.g., from a sentinel file or env var), read the agent's frontmatter:

```bash
AGENT_FILE="$CLAUDE_PROJECT_DIR/.claude/agents/${CLAUDE_AGENT_NAME}.md"
if [[ -f "$AGENT_FILE" ]]; then
    MODEL=$(grep "^model:" "$AGENT_FILE" | awk '{print $2}')
    if [[ "$MODEL" != *"opus"* ]]; then
        deny "Bash restricted to Opus agents."
    fi
fi
```

**Challenge**: The agent name is also not directly available in the hook environment.

**Approach D: Check Process Arguments**

Inspect `/proc/self/cmdline` or `ps` output for the `--model` flag:

```bash
MODEL_ARG=$(ps -p $PPID -o args= | grep -oP '(?<=--model )\S+' || echo "")
```

**Reliability**: Low — process tree structure varies, parent PID may not be the Claude process.

### Available Environment Variables in Hooks

| Variable | Content | Available In |
|----------|---------|--------------|
| `CLAUDE_PROJECT_DIR` | Project root directory | All hooks |
| `CLAUDE_PLUGIN_ROOT` | Plugin installation directory | All hooks |
| `CLAUDE_ENV_FILE` | Path to persist env vars for session | SessionStart |
| `model` (in JSON input) | Active model ID | SessionStart only |
| Custom env vars from `settings.json` `.env` | User-configured values | All hooks |

---

## 4. Plan Mode Behavior

### Plan Mode Already Restricts Tools

**Confidence: High**

In plan mode (`permission_mode: plan`), Claude Code restricts the agent to read-only tools:
- **Allowed**: Read, Glob, Grep, WebFetch, WebSearch, LS, NotebookRead
- **Blocked**: Edit, Write, Bash, NotebookEdit

So plan mode agents **already cannot use Bash** without any plugin intervention.

### Interaction with PreToolUse Hooks

PreToolUse hooks fire regardless of permission mode. If a tool is already blocked by plan mode, the hook may not fire (the tool call is rejected before reaching the hook). The evidence suggests hooks only fire for tools that pass initial permission checks.

---

## 5. Existing Examples of Model-Conditional Behavior

### No Direct Examples Found

**Confidence: High** — searched ai-mktpl plugins, GitHub, and Claude Code docs

No existing plugin conditionally restricts tools based on the active model. However:

- **`safety-evaluation-script`** uses a configurable model (`SAFETY_EVAL_MODEL` env var) for its evaluation step — demonstrating model-awareness via env vars
- **`tmux-subagent`** passes `--model $MODEL` and `--allowedTools` when launching sub-agents — demonstrating model-specific tool restriction at spawn time
- **Agent frontmatter** already separates model choice from tool availability — Sonnet agents can have different tools than Opus agents

---

## 6. Recommended Approaches (Ranked)

### Approach 1: Static Agent Frontmatter (Simplest, No Plugin)

**Feasibility: Already works today**
**Confidence: High**

Simply add `Bash` to `disallowed_tools` for all non-Opus agents:

```yaml
# orchestrator.md (Sonnet)
model: claude-sonnet-4-6
disallowed_tools:
  - Bash
  - Edit
  - Write

# project-manager.md (Sonnet)
model: claude-sonnet-4-6
disallowed_tools:
  - Bash
  - Edit
  - Write
```

**Pros**:
- Zero implementation effort — already supported
- Per-agent granularity
- No race conditions or env var dependencies
- Self-documenting (visible in agent definition)

**Cons**:
- Must be maintained in every agent file manually
- Not enforced as a universal policy — a new agent could forget to add it
- Doesn't provide the helpful "use Task tool instead" message

### Approach 2: Plugin with SessionStart + PreToolUse (Dynamic, Recommended Plugin Approach)

**Feasibility: High — uses first-party mechanisms**
**Confidence: High** — SessionStart `model` field and `CLAUDE_ENV_FILE` are documented features

Plugin structure:
```
bash-opus-only/
├── .claude-plugin/
│   └── plugin.json
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       ├── capture-model.sh      # SessionStart: captures model
│       └── check-bash-model.sh   # PreToolUse: blocks Bash for non-Opus
└── README.md
```

**hooks.json**:
```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/capture-model.sh"
          }
        ]
      }
    ],
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

**capture-model.sh** (SessionStart hook — captures model to env file):
```bash
#!/usr/bin/env bash
set -euo pipefail
INPUT=$(cat)
MODEL=$(echo "$INPUT" | jq -r '.model // empty')
if [[ -n "$MODEL" && -n "${CLAUDE_ENV_FILE:-}" ]]; then
    echo "export CLAUDE_AGENT_MODEL=\"$MODEL\"" >> "$CLAUDE_ENV_FILE"
fi
```

**check-bash-model.sh** (PreToolUse hook — blocks Bash for non-Opus):
```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../../lib/pretooluse.sh"

# Source the env file to get CLAUDE_AGENT_MODEL set by SessionStart hook
if [[ -n "${CLAUDE_ENV_FILE:-}" && -f "$CLAUDE_ENV_FILE" ]]; then
    source "$CLAUDE_ENV_FILE"
fi

MODEL="${CLAUDE_AGENT_MODEL:-}"

# If model is unknown, default to allow (fail-open)
if [[ -z "$MODEL" ]]; then
    allow
fi

# Allow Opus agents
if [[ "$MODEL" == *"opus"* ]]; then
    allow
fi

# Deny non-Opus with helpful message
deny "Bash tool is restricted to Opus-class agents. Instead, use the Task tool to spawn an Opus sub-agent with Bash access: Task(subagent_type='Bash', prompt='your command here')"
```

**Key insight**: SessionStart hooks receive the `model` field in their JSON input ([source](https://code.claude.com/docs/en/hooks#sessionstart-input)). The `CLAUDE_ENV_FILE` mechanism ([source](https://code.claude.com/docs/en/hooks#persist-environment-variables)) allows persisting the model as an env var for subsequent hooks. No external launcher integration required.

**Open question**: `CLAUDE_ENV_FILE` is documented for Bash commands specifically. Whether env vars written there are also available to PreToolUse hook processes needs empirical verification. If not, the PreToolUse hook can `source "$CLAUDE_ENV_FILE"` directly (shown above as a fallback).

**Pros**:
- Universal enforcement as a plugin — applies to all sessions with the plugin installed
- Custom deny message guides the agent to use Task tool
- Can be installed/removed without modifying agent files
- Uses first-party model detection — no external launcher or manual env var needed
- Matcher targets only Bash (efficient)

**Cons**:
- Two hooks needed (SessionStart + PreToolUse) — slightly more complex
- `CLAUDE_ENV_FILE` availability in PreToolUse hooks needs empirical verification
- Fails open if model can't be determined (safe default, but doesn't enforce)

### Approach 3: Hybrid (Frontmatter + Plugin for Safety Net)

**Feasibility: High**
**Confidence: High**

Combine both:
1. Agent frontmatter `disallowed_tools: [Bash]` on all non-Opus agents (primary enforcement)
2. Plugin with PreToolUse hook as a safety net (catches cases where frontmatter was forgotten)

This provides defense-in-depth.

---

## Open Questions

1. **Does Claude Code pass `disallowed_tools` to the API?** — Agent frontmatter defines it, but does the native Claude Code agent spawning actually enforce it by stripping the tool from the API call? Or is it only advisory?
2. **Can `settings.json` env vars be set per-agent?** — If the `env` block in settings.json could be conditional on agent type, Approach 2 becomes trivial.
3. **Does the hook fire if the tool is already blocked by frontmatter?** — If `disallowed_tools` prevents the tool call before the hook runs, Approach 3's safety net may not work as expected.
4. **What does the system prompt tell the model about available tools?** — The system prompt includes "You are powered by the model named Opus 4.6" — could the model self-enforce by reading its own system prompt? (Unreliable, but interesting.)

---

## Confidence Levels

| Finding | Confidence |
|---------|------------|
| PreToolUse hooks can deny Bash with custom message | **High** — verified from multiple existing implementations |
| Agent frontmatter `disallowed_tools` exists and is defined | **High** — verified from types.ts and agent files |
| SessionStart hooks receive `model` field | **High** — [documented](https://code.claude.com/docs/en/hooks#sessionstart-input) |
| PreToolUse hooks do NOT receive `model` field | **High** — [documented](https://code.claude.com/docs/en/hooks#pretooluse-input) |
| `CLAUDE_ENV_FILE` can persist env vars from SessionStart | **High** — [documented](https://code.claude.com/docs/en/hooks#persist-environment-variables) |
| `CLAUDE_ENV_FILE` vars available in PreToolUse hooks | **Medium** — documented for Bash commands; needs empirical verification for hook processes |
| Plan mode already blocks Bash | **High** — documented Claude Code behavior |
| No existing model-conditional plugin exists | **High** — thorough search found none |
| Hybrid approach (frontmatter + plugin) provides best coverage | **Medium-High** — reasonable inference, not empirically tested |

---

## Sources

### Direct Code Analysis
- `ai-mktpl/.claude/hooks/lib/pretooluse.sh` — PreToolUse helper library (allow/deny/ask)
- `ai-mktpl/.claude/hooks/CLAUDE.md` — Hook documentation with input/output schema
- `ai-mktpl/.claude/hooks/pre-tool-use/warn-force-push.sh` — Example Bash tool interception
- `ai-mktpl/plugins/self-terminate/hooks/PreToolUse/validate-git-state.sh` — Example Bash blocking
- `ai-mktpl/plugins/safety-evaluation-script/hooks/hooks.json` — Plugin hook configuration
- `ai-mktpl/plugins/context-bloat-prevention/.claude-plugin/plugin.json` — Plugin with tool hooks
- `agent-team/.claude/agents/*.md` — Agent frontmatter with model, tools, disallowed_tools
- `agent-team/src/types.ts` — AgentFrontmatter type definition with `disallowed_tools` field

### Documentation
- [Claude Code Hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) — Official hooks documentation
- [Claude Code Plugins](https://code.claude.com/docs/en/plugins) — Plugin system documentation
- [Agent Teams](https://code.claude.com/docs/en/agent-teams) — Agent spawning and configuration

### Related Research
- `agent-team/docs/research/quality-gate-hooks-assessment.md` — Hook-based quality gates analysis
- `agent-team/docs/research/new-claude-code-hooks.md` — TeammateIdle/TaskCompleted hooks research
- `agent-team/docs/research/tool-stripping.md` — Tool restriction mechanisms research
