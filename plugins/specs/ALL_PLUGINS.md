# ai-mktpl Plugin Index

All plugins available in [nsheaps/ai-mktpl](https://github.com/nsheaps/ai-mktpl) under `plugins/`.

Plugins marked **[DEPRECATED]** should not be installed in new projects; use the indicated replacement instead.

---

## Categories

- [Communication & Messaging](#communication--messaging)
- [Code & SCM Utilities](#code--scm-utilities)
- [Agent Behavior & Orchestration](#agent-behavior--orchestration)
- [Developer Tools & Environment](#developer-tools--environment)
- [Cloud & Infrastructure](#cloud--infrastructure)
- [Safety & Permissions](#safety--permissions)
- [Reporting & Productivity](#reporting--productivity)
- [Session & UI](#session--ui)
- [Deprecated](#deprecated)

---

## Communication & Messaging

| Plugin | Description | Skills | Hooks | Commands |
|--------|-------------|--------|-------|----------|
| `discord` | Connect a Discord bot to Claude Code with an MCP server | `access`, `configure`, `forum-thread-creation` | — | — |
| `telegram` | Connect a Telegram bot to Claude Code with an MCP server | `access`, `configure` | — | — |

---

## Code & SCM Utilities

| Plugin | Description | Skills | Hooks | Commands |
|--------|-------------|--------|-------|----------|
| `scm-utils` | Source control management utilities for improving Claude's interactions with branches and PRs, both locally and in CI environments | `auth-user`, `automated-code-review`, `code-review`, `commit`, `fix-review-findings`, `git-worktree`, `post-review`, `pr-review-workflow`, `pr-workflow`, `rebase`, `request-a-review`, `respond-to-review`, `review-code`, `review-commit-messages`, `review-commits`, `review-diff`, `review-pr-contents`, `update-branch`, `validate-review` | PostToolUse | `fix-pr` |
| `git-spice` | Skill for managing stacked Git branches with git-spice (`gs` CLI tool) | `git-spice` | PostToolUse | — |
| `edit-utils` | File editing utilities: auto-formatting and linting for written/edited files with project-aware configuration | `auto-config` | PostToolUse | — |
| `code-simplifier` | Simplify and refine code for clarity, consistency, and maintainability | `code-simplifier` | — | `simplify` |
| `sdlc-utils` | Software development lifecycle utilities — one skill per SDLC phase | `deploy`, `github-issues-task-management`, `implement`, `issue-management`, `iterate-until-good`, `maintain`, `plan`, `review`, `spec-writing`, `test` | — | `relentlessly-fix` |
| `fix-pr` | Relentlessly fix a PR until CI passes; iterates through review, fix, push cycles | — | — | `relentlessly-fix` |
| `data-serialization` | Data format conversion and querying utilities for Claude Code | `data-serialization` | — | — |
| `renovate` | Skills for setting up and debugging Renovate auto-merge | `renovate-setup` | — | — |

---

## Agent Behavior & Orchestration

| Plugin | Description | Skills | Hooks | Rules | Commands |
|--------|-------------|--------|-------|-------|----------|
| `common-sense` | Common-sense rules for AI assistant behavior, bundled as a Claude Code plugin | — | PreToolUse | `answer-before-acting`, `artifact-linking-in-reports`, `bash-scripting`, `code-quality`, `critical-system-instructions`, `documentation-references`, `file-extensions`, `file-placement`, `how-to-politely-correct-someone`, `intellectual-honesty-in-responses`, `mantras-and-incremental-development`, `memory-management`, `never-say-done-prematurely`, `pr-management`, `pr-workflow`, `relay-integrity`, `research-before-broadcasting`, `speech-to-text`, `sub-agent-usage`, `task-completion-criteria`, `task-planning`, `teammate-abstraction`, `todo-management`, `tool-preferences`, `ui-screenshot-evidence`, `using-skills-and-plugins`, `verify-before-blaming`, `when-something-doesnt-work`, `writing-rules` | — |
| `agentic-behavior` | Skills for configuring Claude Code, behavior correction, memory tracking, autonomy rules, and time-context awareness | `brain`, `claude-code`, `continue-work`, `correct-behavior`, `exit`, `incident-tracker`, `restart`, `spec-management`, `time-context` | PostToolUse | `acknowledge-before-working`, `autonomy`, `communication-discipline`, `dont-relay-to-visible-parties`, `message-link-formatting`, `thread-history`, `work-tracking` | — |
| `sequential-thinking` | Set up the sequential-thinking MCP server and auto-configure permissions on session start | `sequential-thinking` | PreToolUse | — | — |
| `task-parallelization` | Intelligent skill to help Claude Code parallelize Task tool calls for batch operations | `task-parallelization` | — | — | — |
| `tmux-subagent` | Launch independent Claude sub-agents in tmux sessions with isolated configurations and real-time monitoring | `tmux-subagent` | — | — | `subagent` |
| `word-vomit` | Capture and process unstructured thoughts ("word vomit") into organized, actionable work items | `word-vomit` | PostToolUse | — | — |
| `self-terminate` | Enable Claude to gracefully terminate its own session | `self-terminate` | PreToolUse | — | — |
| `skills-maintenance` | Systematically maintain, update, and improve existing Claude Code agent skills | `skill-maintenance` | — | — | — |
| `mcp-tooling` | Skills for MCP CLI tools, frameworks, proxy daemoning, and gateway patterns | `mcp-cli-philschmid`, `mcp-gateways`, `mcp-proxy-daemoning`, `mcp-use-framework`, `mcpc-apify` | — | — | — |
| `skill-required` | Enforces skill loading before tool use (hook-based guard) | — | PreToolUse | — | — |
| `command-help-skill` | Intelligent skill that helps users understand and discover slash commands | `command-help` | — | — | — |
| `create-command` | Guided assistance for creating and maintaining slash commands | `slash-command-writing` | — | — | `create-command` |
| `memory-manager` | Intelligent memory management for CLAUDE.md files with smart scope detection | `memory-manager` | — | — | — |
| `deep-research` | Multi-agent deep research system for complex, evidence-based investigations | `binary-inspection`, `deep-research` | — | — | — |
| `plugin-management` | Skill for installing, updating, and managing Claude Code plugins | `plugin-management` | — | — | — |
| `todo-plus-plus` | Enforces commit-on-complete for tasks and provides ephemeral session awareness | `todo-plus-plus` | PostToolUse | — | — |
| `todo-sync` | Automatically syncs todos and plans from `~/.claude/` to the current project's `.claude/` directory | `todo-sync` | PreToolUse | — | — |
| `context-bloat-prevention` | Prevents context window bloat from large tool outputs and oversized conversation history | — | PostToolUse | — | — |
| `session-report` | Generate structured session reports covering git history, GitHub issues, PRs, and tasks | `session-report` | — | — | — |
| `daily-report` | Generate comprehensive daily org-wide reports covering commits, PRs, branches, and issue changes | `daily-report` | — | — | — |

---

## Developer Tools & Environment

| Plugin | Description | Skills | Hooks | Commands |
|--------|-------------|--------|-------|----------|
| `1pass` | Install and manage 1Password CLI (`op`) and `op-exec` in Claude Code sessions | `op`, `op-exec` | PreToolUse | — |
| `mise` | Install and manage mise (tool version manager) in Claude Code sessions | `mise` | PostToolUse | — |
| `github` | GitHub CLI installation, authentication, and workflow skill for Claude Code sessions | `gh`, `github-auth`, `pr-feedback` | PostToolUse | — |
| `github-app` | Env-var driven GitHub App token lifecycle for Claude Code sessions | `github-app-token`, `github-auth` | PostToolUse | — |
| `linear-mcp-sync` | Installs the Linear MCP server and adds hooks to prevent stale ticket updates through hash validation | — | PreToolUse + PostToolUse | — |
| `google-workspace-cli` | Install and manage the Google Workspace CLI (`gws`); per-service skills for Gmail, Calendar, Drive, Docs, Sheets, Slides, Chat, Tasks | `admin`, `calendar`, `chat`, `contacts`, `docs`, `drive`, `gmail`, `google-workspace-cli`, `sheets`, `slides`, `tasks` | PostToolUse | — |
| `remote-config` | Sync an upstream Claude config repo on session start | — | PreToolUse | — |
| `shared-lib` | Internal infrastructure plugin: bundles bash helper libraries used by other plugins | — | PostToolUse | — |

---

## Cloud & Infrastructure

| Plugin | Description | Skills | Hooks | Commands |
|--------|-------------|--------|-------|----------|
| `cloudflare` | Skills for managing Cloudflare developer platform components with Pulumi IaC examples | `ai-gateway`, `d1`, `dns`, `durable-objects`, `images`, `kv`, `pages`, `queues`, `r2`, `stream`, `tunnels`, `vectorize`, `workers`, `workers-ai`, `zero-trust` | — | — |
| `arcane` | Skills for deploying docker-compose stacks via Arcane GitOps with 1Password secrets and GitHub Actions CI/CD | `arcane-gitops` | — | — |
| `proxmox` | Skills for managing Proxmox VE hosts and LXC containers | `proxmox-lxc` | — | — |
| `og-image` | Generate Open Graph images using Claude Code | `og-image` | — | — |
| `zai-glm` | Skills for using z.ai (formerly Zhipu AI) GLM models from Claude Code environments | `glm-models`, `zai-setup` | — | — |

---

## Safety & Permissions

| Plugin | Description | Skills | Hooks | Commands |
|--------|-------------|--------|-------|----------|
| `dangerous-bypass` | Provides controlled bypass patterns for when Claude must override safety checks | `dangerous-bypass` | — | — |
| `safety-evaluation-prompt` | Prompt-based safety evaluation framework for Claude Code operations | — | — | — |
| `safety-evaluation-script` | Script-based safety evaluation for Claude Code tool use decisions | — | PreToolUse | — |
| `permissions-sync` | Sync Claude Code permissions across session restarts and config changes | `permissions-sync` | — | — |
| `web-auto-approve` | Auto-approve common web browsing operations in Claude Code sessions | — | PreToolUse | — |

---

## Reporting & Productivity

| Plugin | Description | Skills | Hooks | Commands |
|--------|-------------|--------|-------|----------|
| `agent-tab-titles` | Sets descriptive terminal tab titles based on current Claude Code agent activity | — | PostToolUse | — |

---

## Session & UI

| Plugin | Description | Skills | Hooks | Commands |
|--------|-------------|--------|-------|----------|
| `statusline` | Display Claude Code status in shell prompts and terminal status lines | `statusline` | — | — |
| `statusline-iterm` | iTerm2-specific status line integration for Claude Code | `statusline-iterm` | — | — |

---

## Deprecated

| Plugin | Replaced By | Notes |
|--------|-------------|-------|
| `correct-behavior` | `agentic-behavior` | Behavior correction now part of agentic-behavior plugin |
| `review-changes` | `scm-utils` | SCM review functionality consolidated into scm-utils |
