# AI Agent Memory Frameworks Comparison

> Research compiled: 2026-03-23

## Framework Overview

| Framework           | Type                 | Storage              | Retrieval                   | Self-Improvement       | License    |
| ------------------- | -------------------- | -------------------- | --------------------------- | ---------------------- | ---------- |
| Mem0                | Memory layer         | Vector DB + Graph    | Semantic search             | Adaptive learning      | Apache 2.0 |
| Letta (MemGPT)      | Full agent platform  | Core/Recall/Archival | Agent-driven tool calls     | Self-editing memory    | Apache 2.0 |
| Codebase Memory MCP | Code knowledge graph | SQLite + WAL         | Graph queries (Cypher-like) | No                     | MIT        |
| Claude-Mem          | Session memory       | SQLite + Chroma      | Hybrid (semantic + keyword) | No                     | —          |
| OpenClaw Skills     | File-based memory    | Markdown files       | File read + search          | Yes (tiered promotion) | MIT-0      |
| Context Engineering | Methodology          | N/A                  | N/A (framework)             | Theoretical            | —          |
| Obsidian Skills     | Vault integration    | Obsidian files       | Vault search                | No                     | —          |

---

## 1. Mem0

**[GitHub](https://github.com/mem0ai/mem0) | [Website](https://mem0.ai)**

### Architecture

Universal memory layer designed to sit between applications and LLMs. Three memory levels:

- **User Memory**: Long-term preferences and characteristics
- **Session Memory**: Conversation-specific context
- **Agent Memory**: State management for autonomous systems

### Storage

- Vector store for semantic similarity matching
- Supports self-hosted or managed (app.mem0.ai)
- Python SDK: `pip install mem0ai`
- Node SDK: `npm install mem0ai`

### Retrieval

- `.search(query, user_id, limit)` — semantic search
- `.add(messages, user_id)` — auto-extract and store
- Auto-extraction from conversations: the system identifies important information and stores it without explicit tagging

### Performance

- 26% accuracy improvement over OpenAI Memory (LOCOMO benchmark)
- 91% faster response times vs full-context
- 90% reduction in token consumption

### Strengths

- Drop-in memory layer (doesn't replace your stack)
- Multi-LLM support
- Managed hosting option
- SDK for both Python and Node.js

### Weaknesses

- No built-in self-improvement beyond adaptive personalization
- Requires external LLM for memory extraction
- Less control over what gets stored vs not

---

## 2. Letta (MemGPT)

**[GitHub](https://github.com/letta-ai/letta) | [Docs](https://docs.letta.com)**

### Architecture

LLM-as-Operating-System paradigm. The model manages its own memory like an OS manages RAM and disk.

### Memory Tiers

| Tier                | Analogy      | Behavior                                                               | Size                |
| ------------------- | ------------ | ---------------------------------------------------------------------- | ------------------- |
| **Core Memory**     | RAM          | Always in-context, agent-editable blocks (persona, goals, preferences) | Configurable limits |
| **Recall Memory**   | Disk Cache   | Searchable conversation history, date/text search tools                | Unlimited           |
| **Archival Memory** | Cold Storage | Vector DB for long-term storage, queried via tool calls                | Unlimited           |

### Key Innovation: Self-Editing Memory

The agent decides what's worth remembering by calling memory functions during its reasoning loop:

- Writes to core, recall, or archival memory
- Searches its own memory tiers when needed
- Strategically forgets (precision over recall)

### Strategic Forgetting

Prioritizes precision and relevance. Avoids "context pollution" — too much irrelevant information degrading performance. This is a departure from traditional RAG which maximizes recall.

### Strengths

- Agent has full control over its own memory
- Computer architecture-inspired design (well-understood metaphor)
- No external memory service needed
- Sophisticated context management

### Weaknesses

- **Letta IS the stack** — adopting it means adopting an entire agent platform
- Can't be used as a drop-in memory layer
- Agent must learn to use memory tools effectively
- Higher complexity to set up

---

## 3. Codebase Memory MCP (DeusData)

**[GitHub](https://github.com/DeusData/codebase-memory-mcp)**

### Architecture

Builds persistent knowledge graphs from codebases. Uses tree-sitter for parsing (64 languages).

### Storage

- **SQLite** with WAL mode, ACID-safe
- RAM-first indexing with LZ4 HC compression
- 12 node types, 18+ edge types

### Retrieval (14 MCP Tools)

- `search_graph` — structured search by label/name/file pattern
- `trace_call_path` — BFS traversal for call chains (depth 1-5)
- `query_graph` — Cypher-like read-only queries
- `detect_changes` — git diff → affected symbols with blast radius
- `get_architecture` — languages, packages, routes, hotspots

### Performance

- Name searches: <10ms
- Cypher queries: <1ms
- Dead-code detection: ~150ms
- Linux kernel (28M LOC): 3 minutes → 2.1M nodes, 4.9M edges

### Integration

Auto-detects and configures 10 agents (Claude Code, Codex, Gemini CLI, Zed, OpenCode, etc.). Injects advisory hooks that recommend graph tools over grep/glob.

### Strengths

- No LLM dependency (purely structural)
- Extremely fast
- Rich query capabilities
- Auto-integration with many agents

### Weaknesses

- Code-only (no general knowledge memory)
- No semantic/natural language memory
- No self-improvement capabilities

---

## 4. Claude-Mem (thedotmack)

**[GitHub](https://github.com/thedotmack/claude-mem)**

### Architecture

- SQLite for sessions, observations, summaries
- Chroma vector DB for hybrid search
- 5 lifecycle hooks for capture
- Web viewer on port 37777

### Progressive Disclosure Retrieval

3-layer approach with ~10x token savings:

1. `search` → compact indices (50-100 tokens)
2. `timeline` → chronological context
3. `get_observations` → full details (500-1000 tokens)

### Privacy

`<private>` tags exclude sensitive content from persistent storage.

### Strengths

- Purpose-built for Claude Code
- Token-efficient retrieval
- Privacy controls
- Real-time monitoring UI

### Weaknesses

- Claude Code specific (less portable)
- Requires worker service running
- No self-improvement beyond observation capture

---

## 5. File-Based Memory (OpenClaw Skills Pattern)

### Architecture

Markdown files in well-known locations serve as both storage and prompt injection.

### Common File Structure

```
~/memory-root/
├── memory.md          # Always loaded (HOT)
├── corrections.md     # Explicit corrections log
├── projects/          # Per-project context (WARM)
├── domains/           # Domain-specific patterns (WARM)
├── archive/           # Decayed patterns (COLD)
└── index.md           # Topic index
```

### Workspace Integration Files

```
workspace/
├── AGENTS.md          # Multi-agent workflows
├── SOUL.md            # Identity, principles, boundaries
├── MEMORY.md          # Curated long-term wisdom
├── SESSION-STATE.md   # Active working memory
├── USER.md            # Human context, preferences
└── memory/
    ├── YYYY-MM-DD.md  # Daily raw capture
    └── working-buffer.md  # Danger zone log
```

### Strengths

- Zero dependencies (just file system)
- Human-readable and editable
- Version-controllable (git)
- Works with any agent that reads files
- Transparent — user sees exactly what's stored

### Weaknesses

- No semantic search (relies on keyword matching)
- Linear scaling (more files = slower scanning)
- No automatic relevance scoring
- Requires disciplined file management
- Memory injection consumes context window tokens

---

## 6. Context Engineering (Methodology)

**[GitHub](https://github.com/davidkimai/Context-Engineering)**

### Not a Framework — A Discipline

Defines context engineering as "the delicate art and science of filling the context window with just the right information for the next step."

### Progressive Complexity Model

1. **Atoms/Molecules**: Single prompts, few-shot examples
2. **Cells/Organs**: Persistent memory, multi-agent, state management
3. **Neural Systems/Fields**: Reasoning frameworks, cognitive tools
4. **Meta-Recursion**: Self-reflecting systems, recursive improvement

### Key Research References

- **MEM1** (Singapore-MIT): Reasoning-driven memory consolidation — compress interactions into compact internal states
- **Cognitive Tools** (IBM Zurich): Structured prompt templates as modular reasoning scaffolds (26.7% → 43.3% on AIME2024)
- **Token Budget Optimization**: Every token tracked for cost/latency

### Applicable Patterns

- Context pruning over context accumulation
- Retrieval augmentation for fact grounding
- Control flow for complex task management
- Ruthless deletion over padding

---

## 7. Obsidian Skills (kepano)

**[GitHub](https://github.com/kepano/obsidian-skills)**

### Integration Approach

Transforms Obsidian vaults into agent-accessible knowledge stores.

### Available Skills

| Skill             | Capability                                     |
| ----------------- | ---------------------------------------------- |
| obsidian-markdown | Create/edit .md files with Obsidian syntax     |
| obsidian-bases    | Manage .base files with views/filters/formulas |
| json-canvas       | Build .canvas files with visual connections    |
| obsidian-cli      | Vault operations via CLI                       |
| defuddle          | Extract clean markdown from web pages          |

### Significance

Bridges human-curated knowledge bases with agent reasoning. Enables agents to use Obsidian as a structured memory store that humans also maintain and curate.

---

## 8. Hindsight (Vectorize.io)

**[Website](https://hindsight.vectorize.io) | MIT License**

MCP-first open-source memory server designed to plug directly into MCP-compatible agents.

### Four Memory Networks (Mimicking Human Memory)

| Network | Content |
|---------|---------|
| **World** | Facts about the external world |
| **Experiences** | The agent's own past experiences |
| **Opinion** | Beliefs with confidence scores |
| **Observation** | Complex mental models derived by reflecting on facts and experiences |

### Three Core Operations
- `retain` (store), `recall` (search), `reflect` (reason)

### Mental Models
Living documents that auto-update as memories grow. E.g., "Create a mental model summarizing my project architecture." Generation runs in background via LLM.

### Retrieval
Four parallel retrieval strategies with cross-encoder reranking. 91.4% vs 49.0% advantage over single-strategy search on LongMemEval.

### Strengths
- MCP-native (zero glue code for Claude Code, Cursor, etc.)
- Fully self-hostable with Docker
- Mental models are a unique concept

### Weaknesses
- Early stage, less battle-tested
- Requires LLM at retrieval time for reranking

---

## Key Architectural Insights

1. **Extraction-consolidation spectrum**: Mem0/Zep use external LLM pipelines. Letta delegates to the agent. LangMem offers both (hot path vs background). Tradeoff: control vs cost.

2. **Temporal reasoning is unsolved**: Only Zep has a principled bi-temporal model. As agents operate over longer time horizons, this becomes critical.

3. **No-LLM retrieval advantage**: Zep requires no LLM calls at retrieval time (hybrid search handles everything), giving fundamental latency and cost advantages for read-heavy workloads.

4. **MCP is the integration standard**: Mem0 (OpenMemory), Hindsight, Anthropic's reference server, Microsoft Foundry all converge on MCP tools for memory consumption.

5. **Prompt optimization is underexplored**: LangMem's Prompt Optimizer is the ONLY system that explicitly treats the agent's system prompt as evolvable procedural memory. This is a genuinely different approach to agent improvement that other frameworks have not adopted.
