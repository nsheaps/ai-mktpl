---
name: init
description: >
  Use this skill when the user runs /init or asks to "initialize a CLAUDE.md",
  "set up CLAUDE.md for this repo", "bootstrap Claude Code for this project",
  "document this codebase for Claude", or "scaffold skills and hooks for this
  project". Runs Claude Code's built-in `/init` prompt, verbatim, to analyze the
  codebase and write a concise CLAUDE.md, and (in the newer variant) optionally
  sets up CLAUDE.local.md, skills, and hooks through a guided interview.
---

# Init

Analyzes the current repository and produces a minimal, high-signal `CLAUDE.md`
(and, in the newer variant, optional `CLAUDE.local.md`, skills, and hooks) — the
same artifacts the built-in command generates, driven by the built-in's own
prompt text, verbatim.

Both prompt variants ship verbatim in this plugin under `assets/prompts/`
(extracted from the CLI binary v2.1.225).

## Two variants (which prompt to use)

The built-in `/init` picks one of two prompts at runtime:

| Variant     | Asset                            | Behavior                                                                  |
| ----------- | -------------------------------- | ------------------------------------------------------------------------- |
| **Classic** | `assets/prompts/init-classic.md` | One-shot: analyze the codebase, write a single `CLAUDE.md`. No interview. |
| **New**     | `assets/prompts/init-new.md`     | Guided 8-phase flow: CLAUDE.md + optional CLAUDE.local.md, skills, hooks. |

In the binary, the choice is made by a toggle (internally `Uc_`):

```js
// new variant when either is set, else classic
Boolean(env.CLAUDE_CODE_NEW_INIT) || featureFlag("tengu_slate_harbor_experiment");
```

- The **classic** prompt is the stable, long-standing behavior and the safe
  default for this plugin.
- The **new** prompt is the skills/hooks-aware experiment. Use it when the user
  asks for skills/hooks setup, passes `--new`, or has `CLAUDE_CODE_NEW_INIT` set
  in their environment.

This skill defaults to **classic** unless the user opts into new (see Procedure).

## Prerequisites

- A repository to analyze (run from its root). No network or extra tooling
  required — the whole flow is prompt-driven.
- For the **new** variant's optional hook setup, the user's environment should
  have whatever formatter/linter the hook will call; the prompt probes for this.

## Procedure

### Step 1 — Choose the variant

Pick **new** if any of these hold; otherwise use **classic**:

- The user passed `--new` (or `--classic` forces classic).
- `CLAUDE_CODE_NEW_INIT` is set to a truthy value in the environment
  (`echo "${CLAUDE_CODE_NEW_INIT:-}"`).
- The user explicitly asked to also set up skills and/or hooks.

If you cannot tell, default to **classic** and mention the `--new` option.

### Step 2 — Load the prompt

Read the chosen asset and follow it as your own instructions for the rest of the
turn:

- Classic → `${CLAUDE_PLUGIN_ROOT}/assets/prompts/init-classic.md`
- New → `${CLAUDE_PLUGIN_ROOT}/assets/prompts/init-new.md`

The prompt body IS the procedure. Execute it directly — do not summarize it back
to the user first.

### Step 3 — Execute the prompt against this repo

- **Classic:** Analyze the codebase (build/test/lint commands, big-picture
  architecture), then write `CLAUDE.md` at the repo root, prefixed exactly as the
  prompt specifies. If a `CLAUDE.md` already exists, propose improvements instead
  of blindly overwriting.
- **New:** Run the 8 phases in order — Phase 0 (check for existing CLAUDE.md),
  Phase 1 (AskUserQuestion: which files + whether to add skills/hooks), Phase 2
  (explore the codebase via a subagent), Phase 3 (fill gaps, synthesize a
  proposal, build a preference queue), Phase 4 (write CLAUDE.md), Phase 5 (write
  CLAUDE.local.md and gitignore it), Phase 6 (create skills under
  `.claude/skills/<name>/SKILL.md`), Phase 7 (optimizations: GitHub CLI, linting,
  hooks), Phase 8 (summary + next steps). Honor every AskUserQuestion gate — the
  user approves before anything is written.

### Step 4 — Deliver

Tell the user which files you wrote and the key points captured in each. Remind
them these files are a starting point they should review and can re-run `/init`
to refresh.

## Notes on fidelity

- Both prompts are reproduced **verbatim** from the CLI binary (v2.1.225), minus
  two pieces that require built-in machinery this plugin can't reproduce:
  - The new-init prompt's two Codex/Gemini foreign-agent **import** conditionals
    (they invoke the built-in `tengu_import` flow to pull in `AGENTS.md` /
    `GEMINI.md` from other agents). Everything else in the 8-phase flow is intact.
  - Nothing was cut from the classic prompt except its optional import line.
- The new variant's Phase 7 references the built-in `update-config` skill for
  hook construction and Phase 8 references official plugins (`skill-creator`,
  `frontend-design`, `playwright`) — those are Claude Code features, not part of
  this plugin. The prompt still names them because it is reproduced verbatim;
  they degrade gracefully if unavailable.
- The classic prompt writes exactly one file (`CLAUDE.md`) and never asks
  questions — that is the intended one-shot behavior, not a limitation.

## Troubleshooting

| Symptom                                      | Fix                                                                             |
| -------------------------------------------- | ------------------------------------------------------------------------------- |
| Not sure which variant the user wants        | Default to classic; offer `--new` for skills/hooks setup.                       |
| New variant references `update-config` skill | That's a built-in Claude Code skill; if absent, construct hooks manually.       |
| Existing CLAUDE.md would be overwritten      | Both variants propose improvements/diffs first — never blind-overwrite.         |
| CLAUDE.md comes out bloated                  | Apply the prompt's test: "Would removing this cause Claude to err?" If no, cut. |
