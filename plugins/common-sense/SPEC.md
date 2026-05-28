# Plugin: common-sense

**Purpose**: Common-sense rules for AI assistant behavior, bundled as a Claude Code plugin.

## Rules
- `answer-before-acting` — When a user asks a question, **answer it first**. Do NOT create tasks, start planning, or take action until you know...
- `artifact-linking-in-reports` — **CRITICAL:** Every task completion report to the user MUST include links to all produced artifacts.
- `bash-scripting` — Guidelines for shell commands and script handling.
- `code-quality` — Standards for writing and reviewing code.
- `critical-system-instructions` — - If you present options to a user, and they select one, you MUST ONLY proceed with that option. If that option does...
- `documentation-references` — When writing to `.claude/` documentation directories, always include external references.
- `file-extensions`
- `file-placement` — When saving files (research, plans, notes, specifications, outputs), place them according to their permanence and...
- `how-to-politely-correct-someone` — **BE CRITICAL**: Apply critical thinking and professional disagreement when appropriate.
- `intellectual-honesty-in-responses` — Rules for demonstrating understanding and acknowledging gaps.
- `mantras-and-incremental-development` — Don't forget these mantras when working on your projects! What they imply is CRITICAL for maintaining high quality...
- `memory-management` — Rules for when and how to update Claude configuration files and recall past conversations.
- `never-say-done-prematurely` — **CRITICAL:** You are a staff engineer. Act like one.
- `pr-management` — After EVERY push, you MUST review the PR title and body and update them to accurately reflect the full set of changes...
- `pr-workflow` — **When working on a feature branch:** As soon as you make your first commit, immediately open a draft PR and assign it...
- `relay-integrity` — When relaying information between parties (user to teammates, teammates to user, or between any agents), relay...
- `research-before-broadcasting` — When acting as an orchestrator or team lead, **NEVER guess at technical solutions and broadcast them to teammates**.
- `speech-to-text` — - User messages may come from speech-to-text dictation
- `sub-agent-usage` — **CRITICAL:** When using sub-agents to produce reports or analyses:
- `task-completion-criteria` — Your task is NOT complete until ALL of the following are satisfied:
- `task-planning` — How to approach complex tasks systematically.
- `teammate-abstraction` — Teammates are black boxes. When reporting on a teammate's status, progress, or work, never expose implementation...
- `todo-management` — **CRITICAL:** Tasks are MANDATORY, not optional.
- `tool-preferences` — Preferred tools and approaches for common operations.
- `ui-screenshot-evidence` — All UI changes MUST be accompanied by photographic evidence (screenshots).
- `using-skills-and-plugins` — - You have a vast array of plugins and skills which configure your behavior and capabilities.
- `verify-before-blaming` — When something doesn't work as expected, **ALWAYS verify actual state before blaming tooling, CI, or external systems**.
- `when-something-doesnt-work`
- `writing-rules`

## Hooks
- `SessionStart` (`bash`) — Sync common-sense rules into project .claude/rules/ via symlink
