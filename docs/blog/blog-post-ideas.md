# Blog Post Ideas

Planning document for blog content based on learnings, patterns, and experiences from building the ai-mktpl plugin marketplace for Claude Code.

---

## 1. Building a Plugin Marketplace for AI Coding Agents

**Angle:** The origin story — why we built a curated plugin distribution system for Claude Code, what problems it solves, and how it grew from a handful of personal scripts into 42+ plugins with CI/CD, versioning, and automated marketplace updates.

**Key points:**

- The gap between "AI can code" and "AI can code consistently across projects"
- Why organization-wide configuration matters (21 behavioral rules, 6 custom agents)
- Plugin as the unit of reusable AI behavior — commands, skills, hooks, agents, MCP servers bundled together
- The marketplace.json auto-generation pipeline and why manual edits are forbidden

**Audience:** Teams adopting AI coding tools at scale, platform engineers building developer tooling.

---

## 2. Hooks Are the Killer Feature: Event-Driven AI Agent Behavior

**Angle:** Deep dive into the hook system (PreToolUse, PostToolUse, SessionStart, Stop, UserPromptSubmit) and how event-driven architecture changes how you govern AI agents. The critical insight: no output = defer to defaults, explicit output = override.

**Key points:**

- The permission model — allow, deny, ask — and why "no opinion" must produce zero output
- SessionStart hooks for zero-touch environment setup (mise installation, git fetch, tool provisioning)
- PreToolUse as a safety gate (safety-evaluation plugins, git state validation before termination)
- PostToolUse for advisory feedback (context bloat detection, status updates)
- Real examples: blocking `git add -A`, enforcing clean git state before exit, auto-formatting on edit

**Audience:** Developers building AI agent guardrails, Claude Code plugin authors.

---

## 3. The Auto-Config Pattern: Making AI Plugins Portable Across Projects

**Angle:** How we solved the "works on my machine" problem for AI plugins. The auto-config pattern: no config = no action, auto-detect project toolchain, write explicit settings.

**Key points:**

- The problem: a formatting plugin hardcoded to prettier breaks in a biome project
- 3-tier config resolution (project → user → plugin defaults) with YAML/JSON support
- Auto-config skills that discover project tools and populate `plugins.settings.yaml`
- The edit-utils plugin as a case study — detects prettier/biome/black automatically
- camelCase key convention and why consistency with the JS/TS ecosystem matters

**Audience:** Plugin developers, teams with diverse project toolchains.

---

## 4. Shared Libraries for AI Plugin Development: DRY in Bash

**Angle:** We built 7 reusable bash libraries for plugin hooks and scripts. Here's how we standardized logging, config resolution, tool installation, and permission management across 42 plugins — and why bash was the right (and wrong) choice.

**Key points:**

- The evolution from duplicated `_json_msg()` patterns to `hook-output.sh`
- Three logging tiers: `log.sh` (basic), `hook-output.sh` (simple JSON), `hook-logging.sh` (full lifecycle with steps, log files, error blocks)
- `plugin-config-read.sh` — 3-tier config resolution with yq/jq fallback
- `tool-install.sh` — project-local binary installation with background/foreground modes
- Double-source guards, symlink-at-dev → copy-at-install, and the "never use raw echo" rule
- Why bash: every CI runner and container has it. Why not bash: error handling is painful

**Audience:** DevOps engineers, plugin platform builders, bash enthusiasts/skeptics.

---

## 5. Teaching AI Agents to Be Honest: Rules, Mantras, and Behavioral Governance

**Angle:** We wrote 21 behavioral rules governing how AI agents work in our org. The most impactful ones aren't about code — they're about honesty, verification, and knowing when to stop.

**Key points:**

- "Verify before blaming" — the rule born from an agent filing a bug report based on assumptions, not evidence
- "Never say done prematurely" — why agents must verify their own work
- "Intellectual honesty in responses" — authenticity over excessive agreeableness
- "Relay integrity" — when passing information between agents, don't embellish
- The STEM mindset rule: document hypotheses, record observations, track decisions
- How these rules compound — an honest agent that verifies its work and documents its reasoning is dramatically more useful

**Audience:** Anyone deploying AI agents in production, AI safety practitioners, engineering managers.

---

## 6. CI/CD for AI Plugins: Version Bumps, Marketplace Updates, and the "Never Skip CI" Rule

**Angle:** How we built a CI/CD pipeline that auto-bumps plugin versions, regenerates a marketplace manifest, runs AI-powered code review, and enforces that CI always runs — even when the AI agent really wants to skip it.

**Key points:**

- Semantic versioning for plugins: patch in PRs, auto-bump if forgotten, respect manual bumps
- The CD pipeline: PR auto-version-bump → main safety-net bump → marketplace.json regeneration
- AI code review via Claude Code review workflow (triggered by `request-review` label)
- Why `[skip ci]` is banned for non-automated commits
- The `checkout-as-app` pattern for GitHub App authentication across all workflows
- Mise tasks over custom actions — keeping CI logic locally replicable

**Audience:** DevOps engineers, teams with plugin/package ecosystems, CI/CD enthusiasts.

---

## 7. Safety Evaluation Hooks: Real-Time Guardrails for AI Tool Use

**Angle:** We built two safety evaluation plugins — one prompt-based, one script-based — that evaluate every tool call for safety before execution. Here's what we learned about the tradeoffs between flexibility and latency.

**Key points:**

- The threat model: AI agents with filesystem access, git push, and shell execution
- Prompt-based safety (safety-evaluation-prompt): flexible, natural language rules, but adds latency
- Script-based safety (safety-evaluation-script): fast, deterministic, but brittle to edge cases
- Using haiku-tier models for real-time evaluation (cost/latency tradeoff)
- What we block: `rm -rf`, force pushes, writing to main branch, `git add -A`
- What we learned: safety hooks must never block on "no opinion" (the zero-output pattern)

**Audience:** AI safety engineers, teams deploying autonomous AI agents with real system access.

---

## 8. From 33 Statusline Tools to One Plugin: A Community Research Deep Dive

**Angle:** We cataloged 33 open-source Claude Code statusline tools across 7 languages, analyzed their features and approaches, then built our own plugin. Here's what the community taught us about information density, terminal UX, and the surprising popularity of Rust for CLI tools.

**Key points:**

- The research: 33 tools cataloged by language (Rust, TypeScript, Python, Go, Bash, Ruby), stars, and features
- Common patterns: API usage tracking, cost estimation, git status, model info, token counts
- Unique innovations: Tamagotchi-style gamification, iTerm2 badge integration, tmux powerline segments
- Why Rust dominates: 10+ Rust implementations vs 5 TypeScript, 4 Python — startup time matters for statuslines
- Our approach: configurable plugin with iTerm2 variant, session-aware (parent sessions disable API calls)
- The iTerm2 research rabbit hole — profile automation, color conversion, automatic profile switching

**Audience:** Developer tooling enthusiasts, terminal power users, open-source community observers.

---

## 9. Agent Teams and Orchestration: Lessons from Multi-Agent Workflows

**Angle:** What happens when you give AI agents the ability to spawn other AI agents? We built plugins for tmux-based sub-agents, agent team orchestration, and task parallelization. Here's what worked, what didn't, and why the permission model is everything.

**Key points:**

- The agent team permission model: orchestrators create teams but don't do work; teammates use background sub-agents
- `CLAUDE_CODE_PARENT_SESSION_ID` — how child agents disable expensive features (API calls, statusline)
- Task parallelization plugin: the promise and reality of parallel AI work
- tmux sub-agents: launching isolated agents in terminal panes
- The transcript size problem: >10kB lines causing session crashes (transcript-monitor-plugin spec)
- Context bloat prevention: detecting and mitigating context window exhaustion
- Open question: per-agent plugin profiles (the agent-representation spec)

**Audience:** Teams building multi-agent systems, AI orchestration architects.

---

## 10. Token-Efficient Serialization for LLMs: TOON and Beyond

**Angle:** We researched TOON (Token-Oriented Object Notation), a format that achieves 30-60% token reduction vs JSON. Here's what we learned about token-efficient data serialization, when it matters, and when JSON is fine.

**Key points:**

- The problem: JSON wastes tokens on quotes, colons, and braces — 30-60% overhead
- TOON syntax: indentation-based, no quotes for simple strings, minimal punctuation
- Benchmark results: 73.9% accuracy with TOON vs 70.7% with JSON (on specific tasks)
- Implementations: TypeScript, Python, .NET, Java, Go — surprisingly broad ecosystem
- When to use: large structured data in prompts, tool outputs, context passing between agents
- When not to use: small payloads, human-readable config, API boundaries
- Our data-serialization plugin: YAML/JSON/TOON/XML conversion as a practical tool

**Audience:** AI engineers optimizing for cost/context, developers working with LLM APIs.

---

## 11. The Self-Terminating Agent: Graceful Shutdown with Clean Git State

**Angle:** We built a plugin that lets AI agents terminate their own sessions — but only after validating clean git state. The intersection of process management, git hygiene, and the philosophical question: should an AI agent be able to kill itself?

**Key points:**

- The use case: config changes that require restart, completed work, fresh start needed
- The PreToolUse hook: validates no uncommitted changes, no unpushed commits, no untracked files before allowing termination
- SIGINT (graceful interrupt) over SIGTERM/SIGKILL — why signal choice matters
- Claude Code Web vs local CLI: different session semantics, same validation
- The broader pattern: irreversible actions need pre-flight checks (like `--force-with-lease` for pushes)

**Audience:** AI agent developers, DevOps engineers, process management enthusiasts.

---

## 12. Automatic PR Management: Making AI Agents Good Git Citizens

**Angle:** Every AI agent session in our org automatically creates a draft PR, adds a review label, rebases before every push, and keeps the PR description current. Here's how we enforced git citizenship at the agent level.

**Key points:**

- The rule: every branch gets a PR, every push updates the description, every push rebases first
- Draft PRs by default — human review required before merge
- The `request-review` label triggering AI code review automatically
- GH_TOKEN for cross-repo access and PR management
- Rebase before every push — even if you think the branch is up to date
- `--force-with-lease` as the safe force-push pattern
- Why this matters: AI agents can generate dozens of commits per session — PRs prevent chaos

**Audience:** Engineering managers, teams integrating AI agents into their git workflow.

---

## Potential Series / Groupings

### "Building an AI Plugin Platform" (posts 1, 3, 4, 6)

End-to-end series on the technical platform: marketplace, auto-config, shared libs, CI/CD.

### "Governing AI Agents" (posts 2, 5, 7, 11, 12)

Safety, honesty, guardrails, and process management for autonomous AI agents.

### "Research & Community" (posts 8, 10)

Deep dives into community tools and emerging formats.

### "Multi-Agent Systems" (post 9)

Orchestration, parallelization, and the challenges of agent-to-agent collaboration.

---

## Next Steps

- [ ] Prioritize which posts to write first (audience impact vs effort)
- [ ] Identify which posts need additional research or code examples
- [ ] Decide on publishing platform and format (technical blog, dev.to, Medium, personal site)
- [ ] Determine if posts should include runnable code samples or just concepts
- [ ] Consider whether to release associated plugins/tools alongside posts
