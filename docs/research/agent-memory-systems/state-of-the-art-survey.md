# AI Agent Memory Systems: State of the Art Survey (2025-2026)

> Research compiled: 2026-03-23
> Sources: Academic papers, framework documentation, industry analysis

## Memory Taxonomy (CoALA Framework)

The field has converged on a four-type taxonomy from [Princeton's CoALA framework](https://blogs.oracle.com/developers/agent-memory-why-your-ai-has-amnesia-and-how-to-fix-it) (2023), drawn from cognitive science:

| Type | Duration | What It Stores | Implementation Example |
|------|----------|----------------|----------------------|
| **Working Memory** | Seconds to minutes | Intermediate results, plan progress, CoT steps | Context window contents |
| **Episodic Memory** | Long-term | Specific past experiences with timestamps/outcomes | Few-shot examples from interactions |
| **Semantic Memory** | Long-term | Generalized facts, concepts, relationships | Knowledge graphs, vector stores |
| **Procedural Memory** | Long-term | Learned skills, operational knowledge | Voyager's skill library (executable code) |

**Key Insight**: The gap between "has memory" and "no memory" is [often larger than the gap between different LLM backbones](https://arxiv.org/html/2603.07670). Memory architecture investment can yield returns that rival or exceed model scaling.

---

## Additional Frameworks (Beyond Main Comparison)

### Cognee

**[Website](https://www.cognee.ai/) | [GitHub](https://github.com/topoteretes/cognee)** — 7K+ stars, $7.5M seed (OpenAI/Facebook AI Research founders)

ECL (Extract, Cognify, Load) pipeline:
- `.add()` ingests data
- `.cognify()` builds knowledge graph with embeddings (subject-relation-object triplets)
- `.search()` queries via vector similarity + graph traversal

**Key features**:
- Multi-database backend (Neo4j, FalkorDB, KuzuDB for graphs; Redis, Qdrant, Weaviate for vectors)
- Zero-setup defaults (SQLite + LanceDB + Kuzu, all embedded)
- Memory isolation per user/group/shared
- Chain-of-thought graph traversal for multi-hop reasoning

### MemOS

**[GitHub](https://github.com/MemTensor/MemOS) | [Paper](https://arxiv.org/abs/2507.03724)** — v2.0 "Stardust" (Dec 2025)

Treats memory as a first-class OS resource. Three-layer architecture with unified **MemCube** abstraction:

| Memory Type | Description |
|-------------|-------------|
| **Parametric** | Long-term knowledge in model weights |
| **Activation** | Transient cognitive states during inference |
| **Plaintext** | External text for rapid knowledge updates, personalization |

Key features: Async ingestion with millisecond latency, natural language memory correction, multi-agent memory sharing via pub-sub, tool memory for agent planning. OpenClaw plugin achieves 72% lower token usage.

### Zep (Detailed)

**[Website](https://www.getzep.com/) | [Paper](https://arxiv.org/abs/2501.13956)**

Built on **Graphiti**, a temporally-aware knowledge graph engine (Neo4j). Each fact includes `valid_at` and `invalid_at` dates.

**Benchmarks**:
- DMR: 94.8% vs MemGPT's 93.4%
- LongMemEval: Up to 18.5% accuracy improvement, 90% latency reduction
- Retrieval: <200ms

**Key differentiator**: Temporal awareness — tracks how facts change over time, marks outdated facts as invalid. Memory without time context leads to stale/contradictory information.

### LangMem (LangChain)

**[Blog](https://blog.langchain.com/langmem-sdk-launch/) | [Docs](https://langchain-ai.github.io/langmem/concepts/conceptual_guide/)**

Pure functions for memory management (extract, update, remove, consolidate) + prompt optimization.

Three memory types:
- **Semantic**: Collections (searchable knowledge) + Profiles (strict schema by user/agent)
- **Episodic**: Few-shot examples distilled from longer interactions
- **Procedural**: Learned procedures saved as updated prompt instructions (algorithms: metaprompt, gradient, prompt_memory)

### Additional MCP Memory Servers

| Server | Approach |
|--------|----------|
| **[memory-mcp](https://github.com/yuvalsuede/memory-mcp)** | Writes to CLAUDE.md with confidence decay (progress: 7 days, context: 30 days, architecture: never) |
| **[Basic Memory](https://docs.basicmemory.com)** | Semantic search across Claude Code, Cursor, Codex, VS Code, Obsidian |
| **[MCP Memory Keeper](https://github.com/mkreyman/mcp-memory-keeper)** | Intercepts `/compact`, forces context save. 500 insights: 9,380 → 462 tokens (20x reduction) |
| **[@modelcontextprotocol/server-memory](https://lobehub.com/mcp/randall-gross-claude-memory-mcp)** | Official Anthropic local knowledge graph (SQLite) |

---

## Self-Improvement Research

### Reflection Architectures

**[Reflexion](https://arxiv.org/abs/2405.06682)**: Agents reflecting on failures before retrying. Structured reflections (instructions + explanation + solution) significantly outperform minimal ones (retry/keywords). Statistical significance: p < 0.001.

**[Multi-Agent Reflexion (MAR)](https://arxiv.org/html/2512.20845)**: Separates acting, diagnosing, critiquing, and aggregating across diverse reasoning personas. +3 on HotPotQA, 76.4 → 82.6 on HumanEval pass@1.

**[VIGIL](https://arxiv.org/pdf/2512.07094)**: Self-healing runtime supervising sibling agents. Ingests behavioral logs, produces structured emotional representations.

**[Dual-Loop Reflection](https://www.nature.com/articles/s44387-025-00045-3)** (npj AI): Extrospection (self-critique) builds reflection bank, retrieved during future reasoning for introspection.

### Self-Evolving Agents

**[Voyager](https://arxiv.org/abs/2305.16291)**: Foundational work. First LLM-powered embodied lifelong learning agent. Three components:
1. Automatic curriculum
2. Ever-growing skill library of executable code
3. Iterative prompting with environment feedback + execution errors + self-verification

Skills are temporally extended, interpretable, and compositional. Alleviates catastrophic forgetting.

**[EvolveR](https://arxiv.org/html/2510.16079v1)**: Closed-loop experience lifecycle:
- Offline Self-Distillation → synthesizes trajectories into reusable strategic principles
- Online Interaction → retrieves distilled principles to guide decisions

**[SAGE](https://arxiv.org/html/2409.00872v2)** (Self-evolving Agents with Reflective and Memory-augmented Abilities): 2.26x improvement on closed-source models, 57.7%-100% on open-source.

**[Self-Challenging Agents](https://yoheinakajima.com/better-ways-to-build-self-improving-ai-agents/)** (NeurIPS 2025): LLM plays challenger + executor. RL on self-generated data doubles tool-use benchmark performance.

**[SEAL](https://yoheinakajima.com/better-ways-to-build-self-improving-ai-agents/)** (NeurIPS 2025): Models generate self-edit instructions → fine-tuning examples. Factual QA: 33.5% → 47%. Some few-shot: 0% → 72.5%.

**[ELL Framework](https://arxiv.org/html/2508.19005v5)** (Experience-driven Lifelong Learning): Even GPT-5 achieves only 17.90/100, revealing vast gap in autonomous learning.

### Context Engineering Research

**[ACE](https://arxiv.org/abs/2510.04618)** (Agentic Context Engineering): Treats contexts as evolving playbooks. Three components: Generator, Reflector, Curator. +10.6% on agent benchmarks, +8.6% on finance tasks.

**[A-MEM](https://arxiv.org/abs/2502.12110)** (Agentic Memory): Based on Zettelkasten method. New memories trigger updates to contextual representations of existing memories.

**[GAM](https://venturebeat.com/ai/gam-takes-aim-at-context-rot-a-dual-agent-memory-architecture-that/)** (General Agentic Memory): Dual-agent — one captures everything, another retrieves the right things. JIT compilation analogy.

### Metacognitive Learning

**[ICML 2025 Position Paper](https://openreview.net/forum?id=4KhDd0Ozqe)**: Argues truly self-improving agents require intrinsic metacognitive learning — agents that reflect on what they know, how they learn, and how well their strategies work, then adapt.

---

## Retrieval Patterns Comparison

| System | Retrieval Type | Mechanism |
|--------|---------------|-----------|
| CLAUDE.md | Auto (full load) | Entire file injected at session start |
| Auto Memory | Auto (full load) | MEMORY.md injected into system prompt |
| Mem0 | Auto + On-demand | Semantic similarity to current context |
| Zep | Auto + On-demand | Semantic + graph traversal, temporal filtering |
| Letta/MemGPT | Agent-driven | Agent decides when to search/retrieve via tools |
| Cognee | On-demand | Vector similarity + graph traversal (multi-hop) |
| LangMem | Programmatic + Agent-driven | Developer or agent controls via functions |
| MemOS | Scheduled | MemScheduler orchestrates retrieval |
| A-MEM | Auto-linking | New memories trigger updates to related memories |
| Basic Memory | On-demand | Semantic search via MCP tools |
| claude-mem | Auto + On-demand | Auto-injection + 3-layer search tools |

---

## Emerging Trends

1. **Hybrid storage is winning** — Combining knowledge graphs (structured relationships, temporal tracking) with vector embeddings (semantic similarity). Pure vector or pure graph approaches are giving way to hybrid.

2. **Memory as OS** — MemOS, Letta, and EverMemOS frame memory management as an OS concern with scheduling, garbage collection, and tiered storage.

3. **Agent-controlled memory** — Shift from developer-managed (programmatic) to agent-managed (agentic) memory is accelerating. Self-editing agents outperform static retrieval.

4. **Temporal awareness** — Facts need `valid_at`/`invalid_at` timestamps. Memory without time context leads to stale/contradictory information.

5. **File-based is viable for coding assistants** — CLAUDE.md + Markdown memory files remain practical: portable, debuggable, version-controllable, zero infrastructure.

6. **Structured reflection > raw retry** — Multi-agent reflection (separate critic, executor, aggregator) further improves over single-agent reflection.

7. **Skill libraries are strongest procedural memory** — Storing executable code (Voyager) or prompt updates (LangMem) outperforms raw text descriptions.

8. **PostgreSQL + pgvector as default infrastructure** — Rather than specialized vector databases, convergence on PostgreSQL extensions at moderate scale.

9. **Confidence decay matters** — Progress memories should fade (7 days), context memories slowly (30 days), architecture/decisions never.

10. **Memory investment > model scaling** — Multiple papers confirm memory architecture yields returns comparable to or exceeding model scaling.

---

## Sources

- [Memory in the Age of AI Agents (arXiv survey)](https://arxiv.org/abs/2512.13564)
- [Memory for Autonomous LLM Agents Survey](https://arxiv.org/html/2603.07670)
- [Top 10 AI Memory Products 2026](https://medium.com/@bumurzaqov2/top-10-ai-memory-products-2026-09d7900b5ab1)
- [6 Best AI Agent Memory Frameworks 2026](https://machinelearningmastery.com/the-6-best-ai-agent-memory-frameworks-you-should-try-in-2026/)
- [Memory for AI Agents: Context Engineering](https://thenewstack.io/memory-for-ai-agents-a-new-paradigm-of-context-engineering/)
- [AI Agent Memory Types (IBM)](https://www.ibm.com/think/topics/ai-agent-memory)
- [Making Sense of Memory in AI Agents](https://www.leoniemonigatti.com/blog/memory-in-ai-agents.html)
- [AI Agent Memory Architecture (Redis)](https://redis.io/blog/ai-agent-memory-stateful-systems/)
- [Claude Code Memory Docs](https://code.claude.com/docs/en/memory)
- [File-Based Memory Analysis (DEV)](https://dev.to/imaginex/ai-agent-memory-management-when-markdown-files-are-all-you-need-5ekk)
- [Mem0 Paper](https://arxiv.org/abs/2504.19413) | [Zep Paper](https://arxiv.org/abs/2501.13956) | [MemGPT Paper](https://arxiv.org/abs/2310.08560)
- [MemOS Paper](https://arxiv.org/abs/2507.03724) | [Voyager Paper](https://arxiv.org/abs/2305.16291)
- [Reflexion](https://arxiv.org/abs/2405.06682) | [ACE](https://arxiv.org/abs/2510.04618) | [A-MEM](https://arxiv.org/abs/2502.12110)
- [EvolveR](https://arxiv.org/html/2510.16079v1) | [SAGE](https://arxiv.org/html/2409.00872v2) | [ELL](https://arxiv.org/html/2508.19005v5)
- [ICML 2025 Metacognitive Learning](https://openreview.net/forum?id=4KhDd0Ozqe)
- [ICLR 2026 MemAgents Workshop](https://openreview.net/pdf?id=U51WxL382H)
