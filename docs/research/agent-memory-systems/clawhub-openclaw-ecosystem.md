# ClawHub / OpenClaw Ecosystem Research

> Research compiled: 2026-03-23
> Sources: ClawHub.ai, GitHub openclaw/openclaw, web research

## Overview

[OpenClaw](https://github.com/openclaw/openclaw) (formerly Clawdbot) is an open-source personal AI assistant created by Peter Steinberger. With 247K+ GitHub stars, it's the fastest-growing repo in GitHub history. [ClawHub](https://clawhub.ai) is its skill/plugin marketplace with 13,700+ skills (5,200+ curated).

OpenClaw runs locally and connects to messaging platforms (WhatsApp, Telegram, Slack, Discord, etc.). It supports voice, canvas rendering, browser control, and multi-agent coordination.

## Architecture

```
Messaging Platforms → Gateway (ws://127.0.0.1:18789) → Pi Agent + CLI + WebChat + Apps
```

### Key Components
- **Gateway**: Central control plane for sessions, channels, tools, and events
- **Session Model**: Main sessions + group isolation + activation modes
- **Skills Platform**: Three-tier (bundled, managed, workspace)
- **Tools**: Browser CDP, canvas, node actions, cron, webhooks, sessions_* coordination
- **Model Support**: Extended thinking modes (off through xhigh)

## Memory & Self-Improvement Skills (Deep Dive)

### 1. Self-Improving + Proactive Agent (ivangdavila)

**[ClawHub Link](https://clawhub.ai/ivangdavila/self-improving)**

The most comprehensive self-improvement system. Uses a three-tier memory architecture stored locally in `~/self-improving/`.

#### Memory Tiers

| Tier | Location | Size Limit | Access Pattern |
|------|----------|------------|----------------|
| **HOT** | `memory.md` | ≤100 lines | Always loaded |
| **WARM** | `projects/`, `domains/` | ≤200 lines each | Load on demand |
| **COLD** | `archive/` | Unlimited | Explicit query only |

#### Promotion/Demotion Rules
- **Promote to HOT**: Pattern used 3x within 7 days
- **Demote to WARM**: Unused 30 days
- **Archive to COLD**: Unused 90 days
- **Never delete** without explicit user confirmation

#### File Structure
```
~/self-improving/
├── memory.md          # HOT tier - always loaded
├── index.md           # Topic index with line counts
├── heartbeat-state.md # Maintenance markers
├── corrections.md     # Last 50 explicit corrections
├── projects/          # Per-project learnings
├── domains/           # Code, writing, communications patterns
└── archive/           # Cold storage
```

#### Self-Reflection Mechanism
Triggered after significant work:
1. Compare outcome against stated intent
2. Identify specific improvements
3. Determine if observation is a repeatable pattern

Logging format:
```
CONTEXT: [task type]
REFLECTION: [observation]
LESSON: [actionable change]
```

#### Self-Criticism
Operates via explicit correction signals:
- "No, that's not right..."
- "Actually, it should be..."
- "You're wrong about..."
- "I prefer X, not Y"
- "Stop doing X"

Corrections log to `corrections.md` → evaluated for HOT promotion.

#### Key Design Decision: No Learning from Silence
Inferences require either direct correction OR repeated evidence (3x within 7 days). Ignores one-time instructions, context-specific guidance, and hypothetical scenarios.

---

### 2. Self-Improving Agent (pskoett)

**[ClawHub Link](https://clawhub.ai/pskoett/self-improving-agent)** — 2.6K stars, 4.7K installs

Captures learnings, errors, and corrections for continuous improvement through workspace-based prompt injection.

#### Three Log Files

| File | ID Format | Purpose |
|------|-----------|---------|
| `LEARNINGS.md` | LRN-YYYYMMDD-XXX | Corrections, knowledge gaps, best practices |
| `ERRORS.md` | ERR-YYYYMMDD-XXX | Command failures, exceptions |
| `FEATURE_REQUESTS.md` | FEAT-YYYYMMDD-XXX | User-requested capabilities |

#### Promotion to Project Memory

| Learning Type | Target File |
|---------------|-------------|
| Behavioral patterns | `SOUL.md` |
| Workflow improvements | `AGENTS.md` |
| Tool gotchas | `TOOLS.md` |
| Project conventions | `CLAUDE.md` |

Promotion rule: Patterns reaching 3+ recurrences across 2+ distinct tasks within 30 days become system-prompt guidance.

#### Skill Extraction
When learnings become reusable, they convert to standalone skills via `extract-skill.sh`:
- Recurring issues (2+ See Also links)
- Verified fixes
- Non-obvious solutions
- Broad applicability

#### Hook-Based Automation
- `UserPromptSubmit`: Activates learning evaluation after tasks
- `PostToolUse (Bash)`: Triggers on command errors automatically

---

### 3. Proactive Agent (halthelobster)

**[ClawHub Link](https://clawhub.ai/halthelobster/proactive-agent)** — 615 stars, 116K downloads, v3.1.0

Most battle-tested framework. Three pillars: Proactive, Persistent, Self-Improving.

#### WAL Protocol (Write-Ahead Logging)
Core principle: "Chat history is a BUFFER, not storage. SESSION-STATE.md is your RAM."

Auto-triggers on detecting:
- Corrections ("It's X, not Y")
- Proper nouns
- Preferences
- Decisions
- Specific values

Sequence: **STOP → WRITE to SESSION-STATE.md → THEN respond**

#### Working Buffer Protocol
Survives the "danger zone" between memory flush and compaction:
- At 60% context: clear old buffer, start fresh
- After 60%: append every human message + agent response summary
- Post-compaction: read buffer first to extract critical context

#### Three-Tier Memory

| Layer | File | Purpose | Update Frequency |
|-------|------|---------|------------------|
| Active | SESSION-STATE.md | Current task working memory | Every critical message |
| Daily | memory/YYYY-MM-DD.md | Raw session logs | During session |
| Curated | MEMORY.md | Distilled long-term wisdom | Periodic consolidation |

#### Anticipation Mechanisms
- **Reverse Prompting**: Agent asks discovery questions instead of waiting
- **Pattern Recognition**: Tracks repeated requests, proposes automation at 3+ occurrences
- **Outcome Tracking**: Logs decisions, weekly follow-ups on items >7 days old

#### Self-Improvement Guardrails
- **ADL Protocol**: Anti-Drift Limits (stability > explainability > reusability > scalability > novelty)
- **VFM Protocol**: Value-First Modification scoring (threshold: <50 = skip)
- **Security**: 26% of community skills contain vulnerabilities; audit before install

---

### 4. Claude-Mem (thedotmack)

**[ClawHub Link](https://clawhub.ai) | [GitHub](https://github.com/thedotmack/claude-mem)**

Full lifecycle memory capture for Claude Code sessions.

#### Architecture
- **SQLite**: Primary database for sessions, observations, semantic summaries
- **Chroma**: Vector database for hybrid search (semantic + keyword)
- **5 Lifecycle Hooks**: SessionStart, UserPromptSubmit, PostToolUse, Stop, SessionEnd

#### Progressive Disclosure Retrieval
3-layer workflow with ~10x token savings:
1. `search` → compact indices (~50-100 tokens/result)
2. `timeline` → chronological context
3. `get_observations` → full details (~500-1000 tokens/result)

---

### 5. Other Notable Skills

| Skill | Description |
|-------|-------------|
| **capability-evolver** | Most downloaded. Agents autonomously review session logs and improve behavior |
| **memory-hygiene** | Cleans/optimizes vector memory on demand, prevents stale context drift |
| **agent-memory** | End-to-end encrypted cloud memory for agents |
| **2nd-brain** | Personal knowledge base for capturing info about people, places, tech |
| **active-maintenance** | Automated system health and memory metabolism |
| **agent-self-reflection** | Periodic self-reflection on recent sessions |
| **agent-self-assessment** | Security self-assessment for configuration auditing |

## Cross-Cutting Patterns

1. **File-based memory** dominates — markdown files are the universal persistence format
2. **3x confirmation rule** appears across multiple skills — avoid learning from noise
3. **Tiered memory** (HOT/WARM/COLD or active/daily/curated) is the consensus architecture
4. **Workspace files as memory injection** — AGENTS.md, SOUL.md, MEMORY.md serve as prompt injection points
5. **Self-reflection requires triggers** — post-task completion, post-correction, periodic heartbeats
6. **Explicit > implicit learning** — avoid "learning from silence" to prevent hallucinated preferences
7. **Promotion pipelines** — learnings flow from raw logs → curated memory → system prompt guidance → extractable skills
