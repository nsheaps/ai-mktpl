# Example Output

This is a condensed example of what the prompt-engineer skill produces.
It's deliberately abbreviated — a real output would be 2,000-3,000+ lines.
Use this as a structural reference, not a copy-paste template.

---

## Example Input

> "Build me a CLI tool for managing personal notes. It should store notes as markdown files,
> support tags, full-text search, and sync to a git remote. Written in Rust."

## Example Output (abbreviated)

### `.claude/prompts/init.md`

```markdown
# NoteVault — Personal Note Management CLI

## 1. Project Overview

### 1.1 What We're Building

NoteVault is a CLI tool for managing personal notes stored as Markdown files.
It provides tagging, full-text search, and git-based sync.

### 1.2 Core Value Proposition

Local-first, git-native note management with the speed of Rust and the simplicity
of plain Markdown files. No proprietary format, no cloud lock-in.

### 1.3 Non-Goals (v1)

- No GUI / TUI (CLI only)
- No real-time collaboration
- No encryption at rest
- No mobile app

### 1.4 Tech Stack

| Layer         | Technology              | Why                                |
| ------------- | ----------------------- | ---------------------------------- |
| Language      | Rust                    | Performance, safety, single binary |
| CLI framework | clap                    | Mature, derive-based API           |
| Search        | tantivy                 | Rust-native full-text search       |
| Git           | git2-rs                 | libgit2 bindings                   |
| Test          | cargo test + assert_cmd | Standard + CLI integration         |
| Build         | cargo                   | Standard                           |

## 2. Architecture

[... modules: cli, core, storage, search, sync ...]

## 4. Features

[... note CRUD, tagging, search, git sync ...]

## 5. E2E Test Plan

[... test scenarios for each command ...]

## 11. Claude Code Integration

### 11.2 CLAUDE.md

[Full CLAUDE.md with plugin workflow, review protocol, git-spice stack workflow]

### 11.4 Settings

{
"permissions": { "allow": ["bash(cargo *)", "bash(gs *)", "bash(git *)", ...] },
"extraKnownMarketplaces": {
"nsheaps-ai-mktpl": { ... },
"claude-plugins-official": { ... },
"anthropics-claude-code": { ... }
},
"enabledPlugins": {
"scm-utils@nsheaps-ai-mktpl": true,
"git-spice@nsheaps-ai-mktpl": true,
"ralph-wiggum@anthropics-claude-code": true
}
}

### 11.5 Commands

[/continue with stacked changes + review + Ralph Wiggum]
[/validate, /status, /phase-gate]

### 11.6 Sub-Agents

[test-writer (Rust-specific), reviewer (architecture-specific), doc-writer]

## 12. Task Breakdown

Phase -1: Bootstrap

- T-1.1: settings.json + plugin config
- T-1.2: session-start.sh
- T-1.3: slash commands + sub-agents
- T-1.4: Install plugins (nsheaps/ai-mktpl → official → bundled)
- T-1.5: CLAUDE.md + TASKS.md
- T-1.6: Cargo.toml, .mise.toml, .gitignore
- T-1.7: Init git, push, verify plugins
- T-1.8: Bootstrap complete

Phase 0: Foundation

- T0.1: Cargo workspace, workspace members, shared types
- T0.2: CI workflow (clippy + test)
- T0.3: clap CLI skeleton (--help works)
- T0.4: assert_cmd integration test harness

Phase 1: Core Storage

- T1.1: Note struct + Markdown file read/write
- T1.2: Note metadata (YAML frontmatter)
- T1.3: Tag system (in frontmatter)
- T1.4: `nv new`, `nv edit`, `nv list`, `nv show`, `nv delete`

Phase 2: Search

- T2.1: tantivy index setup
- T2.2: Index on write (auto-index when notes change)
- T2.3: `nv search <query>` with ranked results
- T2.4: Tag-based filtering: `nv list --tag=rust`

Phase 3: Git Sync

- T3.1: git2-rs integration (init, commit, push, pull)
- T3.2: Auto-commit on note changes
- T3.3: `nv sync` (pull + push)
- T3.4: Conflict detection and resolution UX

Phase 4: Polish

- T4.1: Shell completions (bash, zsh, fish)
- T4.2: Man page generation
- T4.3: `nv init` onboarding command
- T4.4: cargo-dist / GitHub release workflow

## 13. Final Notes

### Startup Prompts

**Session 1:**
@.claude/prompts/init.md Read this entire spec. Execute Phase -1.
Install plugins from nsheaps/ai-mktpl first (scm-utils, git-spice),
then anthropics/claude-plugins-official, then anthropics/claude-code (ralph-wiggum).
All work via git-spice stacked branches. Commit after each task.
When done, print what's complete and remind to type "continue".

**Session 2+:**
@.claude/prompts/init.md Re-read spec. gs repo sync && gs repo restack.
Read TASKS.md. For each task: create stacked branch, implement with TDD,
mandatory review (reviewer sub-agent + scm-utils + plugin review),
gs branch submit --fill. At phase end: /ralph-wiggum then /phase-gate.
Complete as many tasks as you can.
```

---

## Key Observations About This Example

1. **The task breakdown maps to stacked branches.** T1.1 → T1.2 → T1.3 → T1.4 forms
   a natural stack. T2.1 can branch from T1.4's merge.

2. **Each task is small.** ~30-60 minutes of agent work. One branch, one PR.

3. **Phase -1 always has the same shape.** Config → plugins → docs → git.
   Only the project-specific details change.

4. **The startup prompts mention the plugin priority explicitly.**
   nsheaps/ai-mktpl → official → bundled.

5. **git-spice commands appear in CLAUDE.md, session-start, and /continue.**
   The agent can't miss them.

6. **The Rust-specific details** (cargo, clippy, tantivy, git2-rs) show how the
   template adapts to different tech stacks while keeping the quality infrastructure
   identical.
