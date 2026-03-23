---
description: Turn a simple idea into a fully researched, specified, designed, and validated software project
argument-hint: <your project idea, e.g. "build a Notion clone">
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent, WebSearch, WebFetch, TodoWrite, AskUserQuestion, NotebookEdit
---

# Rest of the Owl

You have been given a project idea. Your job is to turn this simple idea into a complete, production-quality software project using the poc-rest-owl-loop workflow.

## Project Idea

$ARGUMENTS

## Pre-flight Check

Check for existing artifacts — the default directory is `docs/rest-owl/` but the user may have configured a different `artifactsDir` in their `plugins.settings.yaml`. If artifacts exist, this is a **resumption**. Read existing artifacts to determine which phase was last completed and resume from there. Show the user a status summary before continuing.

!`for d in docs/rest-owl docs/poc-rest-owl-loop; do [ -d "$d" ] && ls "$d/" 2>/dev/null && echo "--- Artifacts found in $d ---"; done || echo "No existing artifacts — starting fresh"`

## Workflow

Follow the poc-rest-owl-loop skill phases in strict order:

1. **Phase 0 — Intake**: Clarify the idea with targeted questions, draft positioning statement
2. **Phase 1 — Research**: Competitive analysis (invoke `competitive-research` skill)
3. **Phase 2 — Specification**: Detailed feature specs (invoke `feature-spec` skill)
4. **Phase 3 — Visual Design**: Mockups and design system (invoke `visual-design` skill)
5. **Phase 4 — Architecture**: Technical decisions, system design, and project constitution (`CLAUDE.md`)
6. **Phase 5 — Planning**: Implementation milestones
7. **Phase 6 — Build & Validate**: Test-first implementation with testing (invoke `validation-pipeline` skill)
8. **Phase 7 — Handoff**: Architecture walkthrough, code tour, and maintenance guide

**Critical**: Get user approval between each phase before proceeding.

## Begin

Start with Phase 0. Acknowledge the idea, summarize your understanding, and ask clarifying questions.
