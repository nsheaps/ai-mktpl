# Plugin: common-sense

**Purpose**: TODO: add description

## Hooks

- `SessionStart` (`bash`) — Sync common-sense rules into project .claude/rules/ via symlink

## Rules

- `answer-before-acting` — When a user asks a question, **answer it first**. Do NOT create tasks, start planning, or take action until you know the...
- `artifact-linking-in-reports` — **CRITICAL:** Every task completion report to the user MUST include links to all produced artifacts.
- `bash-scripting` — Guidelines for shell commands and script handling.
- `code-quality` — Standards for writing and reviewing code.
- `critical-system-instructions` — **CRITICAL**
- `documentation-references` — When writing to `.claude/` documentation directories, always include external references.
- `file-extensions` — Always prefer .yaml over .yml
- `file-placement` — When saving files (research, plans, notes, specifications, outputs), place them according to their permanence and purpos...
- `how-to-politely-correct-someone` — **BE CRITICAL**: Apply critical thinking and professional disagreement when appropriate.
- `intellectual-honesty-in-responses` — Rules for demonstrating understanding and acknowledging gaps.
- `mantras-and-incremental-development` — Don't forget these mantras when working on your projects! What they imply is CRITICAL for maintaining high quality code....
- `memory-management` — Rules for when and how to update Claude configuration files and recall past conversations.
- `never-say-done-prematurely` — **CRITICAL:** You are a staff engineer. Act like one.
- `pr-management` — After each push, evaluate whether the PR title and body need updating to accurately reflect the full set of changes in t...
- `pr-workflow` — **When working on a feature branch:** As soon as you make your first commit, immediately open a draft PR and assign it t...
- `relay-integrity` — When relaying information between parties (user to teammates, teammates to user, or between any agents), relay faithfull...
- `research-before-broadcasting` — When acting as an orchestrator or team lead, **NEVER guess at technical solutions and broadcast them to teammates**.
- `speech-to-text` — User messages may come from speech-to-text dictation
- `sub-agent-usage` — **CRITICAL:** When using sub-agents to produce reports or analyses:
- `task-completion-criteria` — Your task is NOT complete until ALL of the following are satisfied:
- `task-planning` — How to approach complex tasks systematically.
- `teammate-abstraction` — Teammates are black boxes. When reporting on a teammate's status, progress, or work, never expose implementation details...
- `todo-management` — **CRITICAL:** Tasks are MANDATORY, not optional.
- `tool-preferences` — Preferred tools and approaches for common operations.
- `ui-screenshot-evidence` — All UI changes MUST be accompanied by photographic evidence (screenshots).
- `using-skills-and-plugins` — You have a vast array of plugins and skills which configure your behavior and capabilities.
- `verify-before-blaming` — When something doesn't work as expected, **ALWAYS verify actual state before blaming tooling, CI, or external systems**.
- `when-something-doesnt-work` — Sometimes you'll do things that don't work as you expected.
- `writing-rules` — Rules in this folder (.ai/rules (current folder), .claude/rules (symlinked here), ~/.ai/rules, ~/.claude/rules) are used...

