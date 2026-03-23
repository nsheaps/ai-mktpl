# Agent Memory Systems: Comprehensive Report

> Research compiled: 2026-03-23
> Based on analysis of nsheaps' ~270 starred repos, ClawHub/OpenClaw ecosystem, and state-of-the-art memory frameworks

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Memory for Specific Tasks](#1-memory-for-specific-tasks)
3. [Cross-Session Persistent Memory](#2-cross-session-persistent-memory)
4. [Self-Improvement and Reflection](#3-self-improvement-and-reflection)
5. [Architectural Patterns](#architectural-patterns)
6. [Recommendations](#recommendations)

## Related Research Documents

- [Starred Repos Analysis](./starred-repos-analysis.md) — Categorization of all ~270 starred repos
- [ClawHub/OpenClaw Ecosystem](./clawhub-openclaw-ecosystem.md) — Deep dive on OpenClaw skills
- [Memory Frameworks Comparison](./memory-frameworks-comparison.md) — Technical comparison of frameworks

---

## Executive Summary

Agent memory is the defining frontier in AI agent development. After analyzing 270+ repositories, the ClawHub/OpenClaw ecosystem (13,700+ skills), and major memory frameworks (Mem0, Letta/MemGPT, Codebase Memory MCP, Claude-Mem), three clear tiers of memory emerge:

1. **Task-scoped memory** — Working memory for the current task (scratchpads, session state, todo lists)
2. **Cross-session memory** — Persistent context that survives session boundaries (files, databases, vector stores)
3. **Self-improving memory** — Systems that learn, reflect, and auto-configure from past execution

The ecosystem is converging on several patterns: **file-based memory** for simplicity and transparency, **tiered promotion** (HOT/WARM/COLD) for managing memory lifecycle, **3x confirmation** before promoting observations to permanent memory, and **workspace files as prompt injection** (CLAUDE.md, AGENTS.md, SOUL.md) as the primary mechanism for injecting persistent context.

---

## 1. Memory for Specific Tasks

### What It Is
Working memory that exists only during the execution of a specific task. Analogous to RAM — fast, immediately accessible, disposable after the task ends.

### Approaches

#### 1.1 Session State Files
**Used by**: Proactive Agent, OpenClaw skills

```
SESSION-STATE.md — Active working memory, written via WAL protocol
```

The WAL (Write-Ahead Logging) protocol is the most sophisticated approach: **STOP → WRITE → THEN RESPOND**. Before responding, the agent writes important details to a session state file. This prevents context loss during response composition.

Auto-triggers on detecting:
- Corrections, proper nouns, preferences, decisions, specific values

#### 1.2 Todo Lists and Scratchpads
**Used by**: Claude Code (built-in TodoWrite tool), most coding agents

Simple task-tracking within a single session. The Claude Code TodoWrite tool tracks progress with states (pending, in_progress, completed) but doesn't persist across sessions.

#### 1.3 Working Buffers
**Used by**: Proactive Agent

Survival mechanism for context compaction (the "danger zone"):
- At 60% context usage: clear old buffer, start fresh
- After 60%: append every exchange as 1-2 sentence summary
- Post-compaction: read buffer first to recover critical context

This is the most mature approach to handling the fundamental problem of finite context windows.

#### 1.4 In-Context Memory Blocks
**Used by**: Letta/MemGPT (Core Memory)

Always-in-context, agent-editable blocks (persona, goals, preferences). Size-limited and configurable. The agent writes to these blocks during reasoning, and they're always present in the system prompt.

#### 1.5 Task-Specific Knowledge Graphs
**Used by**: Codebase Memory MCP

For code-specific tasks, builds a persistent knowledge graph with 12 node types and 18+ edge types. Sub-millisecond queries. Not general-purpose memory but extremely effective for code understanding tasks.

### Key Insight
Task-scoped memory benefits most from **write-ahead patterns** (capture before responding) and **progressive disclosure** (load minimal context, expand on demand). The Working Buffer pattern from the Proactive Agent is the most sophisticated solution to context window management.

---

## 2. Cross-Session Persistent Memory

### What It Is
Memory that persists across session boundaries, allowing an agent to "remember" past interactions, decisions, and context. The critical challenge is **retrieval** — finding the right memories at the right time.

### Approaches

#### 2.1 File-Based Memory (Markdown Files)

**Used by**: OpenClaw skills (self-improving, proactive-agent), Claude Code (CLAUDE.md), most coding agents

The dominant pattern in the current ecosystem. Memory is stored as markdown files in well-known locations.

**Advantages**:
- Zero dependencies
- Human-readable and editable
- Version-controllable (git)
- Works with any agent that reads files
- Transparent — user sees exactly what's stored

**Disadvantages**:
- No semantic search
- Linear scaling (more files = slower)
- No automatic relevance scoring
- Consumes context window tokens

**Common Structure**:
```
~/memory-root/
├── memory.md          # Always loaded (HOT)
├── corrections.md     # Explicit corrections log
├── projects/          # Per-project context (WARM)
├── domains/           # Domain-specific patterns (WARM)
├── archive/           # Decayed patterns (COLD)
└── index.md           # Topic index
```

**Retrieval**: File read (always-load for HOT tier), keyword search, manual query. No automatic relevance scoring.

#### 2.2 Workspace Prompt Injection

**Used by**: OpenClaw, Claude Code (CLAUDE.md)

Special files that are automatically loaded into the agent's context at session start:

| File | Purpose |
|------|---------|
| `CLAUDE.md` / `AGENTS.md` | Operating rules, learned workflows |
| `SOUL.md` | Identity, principles, boundaries |
| `USER.md` | Human's context, goals, preferences |
| `MEMORY.md` | Curated long-term wisdom |

This is the **simplest form of auto-retrieval** — the memory is always present because it's injected into the system prompt. Size-limited by context window constraints.

#### 2.3 Vector Database + Semantic Search

**Used by**: Mem0, Claude-Mem, Zilliz/Claude-Context

**Architecture**: Observations → embeddings → vector DB → semantic similarity search at retrieval time.

**Mem0 Performance**:
- 26% accuracy improvement over OpenAI Memory
- 91% faster response times
- 90% reduction in token consumption

**Claude-Mem Progressive Disclosure**:
1. `search` → compact indices (50-100 tokens/result)
2. `timeline` → chronological context
3. `get_observations` → full details (500-1000 tokens/result)
Result: ~10x token savings by filtering before fetching.

**Retrieval**: Semantic similarity + keyword matching (hybrid search is best). Auto-retrieval possible by searching relevant memories before each response.

#### 2.4 Knowledge Graphs

**Used by**: Codebase Memory MCP, Mem0 (graph component)

**Architecture**: Entities → relationships → graph queries (Cypher-like).

**Codebase Memory MCP**: 14 query tools, sub-millisecond performance, auto-integration with 10 agents. Purely structural (no LLM dependency).

**Retrieval**: Graph traversal, pattern matching, blast-radius analysis. Excellent for structured/relational data, less suitable for unstructured observations.

#### 2.5 Agent-Managed Memory (Self-Editing)

**Used by**: Letta/MemGPT

**Architecture**: The agent itself decides what to remember and what to forget via tool calls.

Three tiers:
- **Core Memory** (always in-context, agent-editable)
- **Recall Memory** (searchable conversation history)
- **Archival Memory** (vector DB, long-term)

**Key Innovation**: Strategic forgetting. Precision over recall. Avoids "context pollution."

**Trade-off**: Letta IS the stack — you must adopt the entire agent platform, not just the memory layer.

#### 2.6 MCP-Based Memory Services

**Used by**: Codebase Memory MCP, various memory MCP servers

**Architecture**: Memory exposed as MCP tools that any compatible client can use.

This is the **most portable** approach — any MCP-compatible agent can use the memory service. The tool interface provides natural auto-retrieval: the agent can call search tools as part of its normal reasoning loop.

### Auto-Retrieval Mechanisms

| Mechanism | How It Works | Pros | Cons |
|-----------|-------------|------|------|
| **Always-load** | File injected at session start | Simple, reliable | Size-limited, consumes tokens |
| **Hook-triggered** | SessionStart/UserPromptSubmit hooks search memory | Automatic, targeted | Adds latency, may miss relevant memories |
| **Agent-initiated** | Agent calls search tools during reasoning | Most flexible | Agent must know to search |
| **Embedding similarity** | Auto-inject similar memories per message | Most intelligent | Requires embedding pipeline |
| **Advisory hooks** | MCP hooks suggest using memory tools | Non-blocking | Agent can ignore suggestions |

### Key Insight
The best cross-session memory combines **always-loaded curated memory** (small, high-value) with **searchable deep storage** (large, queryable on demand). Auto-retrieval works best as a multi-layer approach: always-load the most important 100 lines, then use semantic search for everything else.

---

## 3. Self-Improvement and Reflection

### What It Is
Systems that allow agents to learn from past executions, auto-configure based on experience, and improve their own behavior over time. This is the most nascent and challenging area.

### Approaches

#### 3.1 Correction Logging and Pattern Detection

**Used by**: Self-Improving Agent (ivangdavila), Self-Improving Agent (pskoett)

**Mechanism**:
1. Detect explicit corrections ("No, that's not right...", "Actually, it should be...")
2. Log to `corrections.md` or `LEARNINGS.md`
3. Track occurrence count and recency
4. Promote to permanent memory when pattern reaches threshold (3x within 7 days)

**Critical Design Decision**: **No learning from silence**. Only learn from explicit corrections or repeated evidence. This prevents hallucinated preferences.

#### 3.2 Self-Reflection Triggers

**Used by**: Self-Improving Agent, Proactive Agent, agent-self-reflection

**When triggered**:
- After multi-step task completion
- After receiving user feedback (positive or negative)
- After fixing bugs or mistakes
- When noticing potential output improvements
- Periodic heartbeat checks

**Reflection Format**:
```
CONTEXT: [task type]
REFLECTION: [observation]
LESSON: [actionable change]
```

#### 3.3 Tiered Promotion Pipeline

**Used by**: Self-Improving Agent (ivangdavila), Self-Improving Agent (pskoett)

The most structured approach to self-improvement:

```
Raw Observation → Corrections Log → Warm Memory → HOT Memory → System Prompt
                                                                     ↓
                                                              Extractable Skill
```

**Promotion criteria**:
- 3x occurrence within 7 days → promote to HOT
- 3+ recurrences across 2+ tasks within 30 days → system prompt guidance
- Broadly applicable patterns → standalone skill extraction

**Demotion**:
- Unused 30 days → WARM
- Unused 90 days → COLD/archive
- Never delete without user confirmation

#### 3.4 Skill Extraction

**Used by**: Self-Improving Agent (pskoett), SkillForge

When learnings become reusable patterns, they're extracted into standalone skills:

**Criteria**:
- Recurring issues (2+ cross-references)
- Verified fixes
- Non-obvious solutions
- Broad applicability

**SkillForge** adds a 4-phase methodology with multi-agent review:
1. Triage (reuse/improve/create/compose)
2. Deep Analysis (11 thinking lenses)
3. Specification & Generation
4. Multi-Agent Synthesis (unanimous consensus required)

#### 3.5 Anticipation and Proactive Behavior

**Used by**: Proactive Agent

Beyond reactive learning, the agent actively anticipates needs:

- **Reverse Prompting**: Asks discovery questions instead of waiting
- **Pattern Recognition**: Tracks repeated requests, proposes automation at 3+ occurrences
- **Outcome Tracking**: Logs decisions, follows up on items >7 days old
- **Growth Loops**: Curiosity questions, pattern tracking, outcome journals

#### 3.6 Self-Configuration Based on Past Execution

**Used by**: Auto-config pattern (ai-mktpl), capability-evolver

**Auto-config**: Agent detects project tooling and auto-configures settings (e.g., detecting prettier vs biome for formatting). Not learning from mistakes, but adaptive configuration.

**Capability-evolver**: Most downloaded OpenClaw skill. Agents autonomously review session logs and improve behavior. Details not fully documented.

#### 3.7 Workspace Self-Modification

**Used by**: Proactive Agent, Self-Improving Agent

Agents modify their own workspace steering files:

| Target | Type of Modification |
|--------|---------------------|
| `AGENTS.md` | Workflow improvements |
| `SOUL.md` | Behavioral patterns |
| `TOOLS.md` | Tool gotchas |
| `CLAUDE.md` | Project conventions |

**Non-destructive**: Additions and amendments only, never deletions without user confirmation.

### Self-Improvement Guardrails

The Proactive Agent defines critical guardrails:

**ADL Protocol** (Anti-Drift Limits):
- Prohibits: fake complexity, unverifiable changes, vague justifications
- Priority: Stability > Explainability > Reusability > Scalability > Novelty

**VFM Protocol** (Value-First Modification):
Score changes: High Frequency (3x), Failure Reduction (3x), User Burden (2x), Self Cost (2x)
Threshold: score <50 = skip the modification

### Key Insight
Self-improvement requires **explicit triggers, confirmation thresholds, and guardrails**. The 3x confirmation rule, anti-drift limits, and never-delete-without-confirmation are essential safety mechanisms. The most effective systems combine correction logging, periodic self-reflection, and structured promotion pipelines with clear demotion paths.

---

## Architectural Patterns

### Pattern 1: Tiered Memory (HOT/WARM/COLD)
- **HOT**: Always loaded, size-limited (~100 lines), highest-value patterns
- **WARM**: Loaded on demand, per-project/domain, medium-value
- **COLD**: Archived, query-only, unlimited size
- Movement: Promotion based on frequency, demotion based on recency

### Pattern 2: Write-Ahead Logging (WAL)
- STOP → WRITE to persistent storage → THEN respond
- Prevents context loss during response composition
- Auto-triggered by detecting important information types

### Pattern 3: Progressive Disclosure
- Start with minimal context injection
- Expand on demand through tool calls
- ~10x token savings vs loading everything upfront

### Pattern 4: 3x Confirmation Rule
- Don't learn from single occurrences
- Require 3 repetitions within 7 days to promote
- Prevents hallucinated preferences and learning from noise

### Pattern 5: Workspace Prompt Injection
- Well-known files (CLAUDE.md, AGENTS.md, SOUL.md) auto-loaded by agent
- Primary mechanism for persistent cross-session context
- Size-limited but zero-configuration

### Pattern 6: Hook-Driven Lifecycle
- SessionStart: Load memories, initialize state
- UserPromptSubmit: Pre-process, inject context
- PostToolUse: Capture observations
- Stop/SessionEnd: Persist session state, generate summaries

### Pattern 7: Promotion Pipeline
```
Observation → Log → Warm Memory → Hot Memory → System Prompt → Skill
```
Each promotion requires meeting a threshold (frequency, recency, breadth).

### Pattern 8: Strategic Forgetting
- Precision over recall
- Remove stale/contradictory context
- Demote unused patterns on a schedule
- Never delete without user confirmation

---

## Recommendations

### For This Plugin Marketplace

Based on this research, a memory/self-improvement plugin for the ai-mktpl ecosystem should:

1. **Start with file-based memory** — Markdown files in `~/.claude/memory/` or project `.claude/memory/`
   - Compatible with existing workspace injection patterns
   - Human-readable, git-trackable
   - Zero external dependencies

2. **Implement tiered memory** — HOT (always-loaded CLAUDE.md additions), WARM (project-specific), COLD (archive)
   - HOT tier: ≤100 lines injected via SessionStart hook
   - WARM tier: Loaded on demand via skill/tool call
   - COLD tier: Searchable archive

3. **Use hooks for lifecycle capture** — SessionStart (load), PostToolUse (observe), Stop (persist)
   - Leverage existing hook-logging.sh and plugin-config-read.sh shared libraries
   - Follow hook output patterns (JSON for hooks, plain text for logging)

4. **Implement correction detection** — Identify explicit user corrections and log them
   - Require 3x confirmation before promoting to permanent memory
   - Never learn from silence

5. **Add self-reflection triggers** — Post-task completion and periodic heartbeats
   - Use subagent (haiku model) for reflection to minimize cost
   - Log reflections with CONTEXT/REFLECTION/LESSON format

6. **Consider MCP integration** — Expose memory as MCP tools for portability
   - `memory_search`, `memory_add`, `memory_forget`
   - Compatible with any MCP client, not just Claude Code

7. **Add semantic search later** — Start simple, add vector search if file-based proves insufficient
   - Chroma or SQLite FTS5 for local search
   - Progressive disclosure pattern for token efficiency

### Priority Order
1. File-based tiered memory with workspace injection (MVP)
2. Hook-driven observation capture
3. Correction logging with 3x promotion
4. Self-reflection triggers
5. MCP tool interface
6. Semantic search upgrade
7. Skill extraction from patterns
