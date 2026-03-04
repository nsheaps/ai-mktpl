---
name: prompt-engineer
description: >
  Generate comprehensive autonomous agent prompts for Claude Code that turn a project idea into
  a fully-specified, self-executing development plan. Use this skill whenever a user describes
  a software project, application, tool, or system they want built and needs an agent prompt
  to drive autonomous development with Claude Code. Also use when the user says things like
  "create a prompt for", "write an init prompt", "set up a new project", "bootstrap prompt",
  "generate a spec", "agentic prompt", or wants to turn any idea into a Claude Code workflow.
  This skill produces the `.claude/prompts/init.md` file and startup prompts that make a
  Claude Code agent fully autonomous with quality gates, plugin infrastructure, stacked
  changes, code reviews, sub-agents, and iterative quality loops.
---

# Prompt Engineer

Generate autonomous Claude Code agent prompts from project ideas.

## What This Skill Produces

Given a user's project description (anything from a one-liner to a detailed spec), this skill
produces:

1. **`.claude/prompts/init.md`** — A comprehensive specification and agent instruction file
2. **Startup prompts** — Copy-paste prompts for Session 1 (bootstrap) and Session 2+ (development)

The generated prompt is self-contained: a Claude Code agent reading it should be able to
bootstrap the entire project, install plugins, create all config, and begin autonomous
development with full quality infrastructure.

## Workflow

### Phase 1: Understand the Request

Interview the user. Extract or ask about:

1. **What** — What are they building? (app, CLI, library, service, etc.)
2. **Why** — What problem does it solve? Who uses it?
3. **Tech stack** — Any preferences? (language, framework, database, hosting)
4. **Scope** — MVP features vs. full vision. What's in v1 vs. later?
5. **Repo** — Where does the code live? (GitHub org/repo, or new?)
6. **Existing work** — Starting from scratch or existing codebase?
7. **Deployment** — How will it ship? (npm, Docker, cloud, app store, static site)
8. **Constraints** — Accessibility, performance, offline, compliance, etc.

Don't ask all at once. Ask the most important 2-3 questions, infer what you can, and iterate.
If the user already gave a detailed description, extract answers from it before asking for gaps.

### Phase 2: Structural Analysis

Before writing the prompt, think through architecture. Read `references/prompt-structure.md`
for the full template. The key sections you need to plan:

1. **Architecture** — Monorepo vs. single package, abstraction layers, platform targets
2. **Phase breakdown** — Decompose the project into 4-8 phases of increasing capability.
   Each phase should be independently deployable/testable. Earlier phases are smaller.
3. **Task decomposition** — Break each phase into tasks (3-10 per phase). Each task should
   be completable in a single agent session and produce a small, reviewable change.
4. **Plugin selection** — Read `references/plugin-hierarchy.md` to select plugins.
   Priority: `nsheaps/ai-mktpl` → `anthropics/claude-plugins-official` → `anthropics/claude-code` → custom.
   Always include `scm-utils` and `git-spice` from `nsheaps/ai-mktpl`.
5. **Quality gates** — Read `references/quality-gates.md` for the review, testing, and
   Ralph Wiggum loop patterns to embed in the prompt.
6. **SCM strategy** — Read `references/scm-strategy.md` for the stacked changes workflow.
   The generated prompt must instruct the agent to use git-spice for small logical stacked PRs.

Present this structural analysis to the user as a summary before writing the full prompt.
Get confirmation or adjustments.

### Phase 3: Generate the Prompt

Read `references/prompt-structure.md` for the full template. Generate the `.claude/prompts/init.md`
file containing all sections. Read `references/claude-code-config.md` for the settings.json,
slash commands, sub-agents, and session-start script patterns.

The generated prompt MUST include all of these (non-negotiable):

- [ ] Project overview with goals, audience, and non-goals
- [ ] Architecture with abstraction layers and package structure
- [ ] Plugin setup (marketplaces, enabled plugins, installation in session-start)
- [ ] `.claude/settings.json` with permissions, marketplaces, enabled plugins
- [ ] `.claude/scripts/session-start.sh` (idempotent bootstrap with plugin install)
- [ ] Slash commands: `/continue`, `/validate`, `/status`, `/phase-gate`
- [ ] Sub-agents: test-writer, reviewer, doc-writer (plus domain-specific ones)
- [ ] `CLAUDE.md` content with plugin workflow and review protocol
- [ ] Task breakdown with phases and numbered tasks
- [ ] Quality gates embedded in task execution (see `references/quality-gates.md`)
- [ ] SCM workflow with git-spice stacked changes (see `references/scm-strategy.md`)
- [ ] Session 1 bootstrap prompt and Session 2+ development prompt
- [ ] E2E test strategy and BDD feature specs
- [ ] Multi-session workflow documentation

### Phase 4: Review and Iterate

After generating the prompt, review it with the user:

1. **Completeness check** — Walk through the checklist above. Is anything missing?
2. **Scope check** — Is the task breakdown reasonable? Too many phases? Too few?
3. **Plugin check** — Are the right plugins selected? Any missing from `nsheaps/ai-mktpl`?
4. **Feasibility check** — Can each task be completed in one session? Are there dependencies?
5. **User feedback** — Ask the user to review and suggest changes.

Iterate until the user is satisfied. The goal is a prompt that, when fed to Claude Code,
produces a working project with minimal human intervention.

### Phase 5: Deliver

Output:

1. The complete `.claude/prompts/init.md` file
2. Session 1 bootstrap prompt (copy-paste ready)
3. Session 2+ continuation prompt (copy-paste ready)
4. A brief "how to use" guide

---

## Reference Files

Read these BEFORE generating the prompt. They contain the patterns and templates.

| File                               | When to Read       | What It Contains                                         |
| ---------------------------------- | ------------------ | -------------------------------------------------------- |
| `references/prompt-structure.md`   | Phase 2-3          | Full template for the generated prompt with all sections |
| `references/plugin-hierarchy.md`   | Phase 2            | Plugin selection rules, known plugins per marketplace    |
| `references/quality-gates.md`      | Phase 2-3          | Review workflow, Ralph Wiggum loop, sub-agent patterns   |
| `references/claude-code-config.md` | Phase 3            | Settings.json, commands, agents, session-start templates |
| `references/scm-strategy.md`       | Phase 2-3          | Git-spice stacked changes workflow and SCM patterns      |
| `references/example-output.md`     | Phase 3 (optional) | Condensed example of a generated prompt for reference    |

---

## Key Principles

1. **The prompt is the product.** It must be self-contained. A Claude Code agent should need
   nothing else to start building.

2. **Plugins over custom.** Always prefer existing plugins from `nsheaps/ai-mktpl`, then
   `anthropics/claude-plugins-official`, then `anthropics/claude-code`. Only define custom
   agents/commands for project-specific logic that no plugin covers.

3. **Small changes, always reviewed.** Every task produces a small, stacked PR via git-spice.
   Every change gets multi-layer review. No exceptions.

4. **The Ralph Wiggum loop is mandatory.** At the end of every phase, the agent must run
   `/ralph-loop` to iteratively re-examine all code until no issues remain.

5. **Sub-agents run in parallel.** The generated prompt must instruct the agent to dispatch
   independent work concurrently — planning + test writing, implementation + docs, etc.

6. **Iterative over perfect.** Get the structure right first, then refine. The user will
   likely want to adjust phases, tech stack, or scope after seeing the first draft.
