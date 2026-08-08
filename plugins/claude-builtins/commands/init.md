---
name: init
description: Analyze this repository and write a concise CLAUDE.md (and optionally CLAUDE.local.md, skills, and hooks), driven by the verbatim prompt extracted from Claude Code's built-in /init
argument-hint: "[--new] [--classic]"
allowed-tools: Task, Read, Write, Edit, Bash(echo:*), Bash(git:*), Bash(which:*), Bash(where:*), Glob, Grep, AskUserQuestion
---

# Init

Analyze the current repository and produce a minimal, high-signal `CLAUDE.md`
(and, in the newer variant, optionally `CLAUDE.local.md`, skills, and hooks).

Both prompt variants are the built-in's own, verbatim — follow the selected one
exactly rather than writing a `CLAUDE.md` from your own judgement.

Invoke the **`init`** skill and follow it end to end. The user's arguments
select which prompt variant runs.

## Arguments

**Format:** `[--new] [--classic]`

| Argument    | Meaning                                                                   |
| ----------- | ------------------------------------------------------------------------- |
| (none)      | Classic one-shot: analyze the codebase, write a single `CLAUDE.md`.       |
| `--new`     | Guided 8-phase flow: CLAUDE.md + optional CLAUDE.local.md, skills, hooks. |
| `--classic` | Force the classic one-shot even if `CLAUDE_CODE_NEW_INIT` is set.         |

If neither flag is given, the skill selects the variant: **new** when
`CLAUDE_CODE_NEW_INIT` is truthy in the environment or the user asked to also
set up skills/hooks, otherwise **classic**.

**Examples:**

- `/init` — write a CLAUDE.md for this repo (classic)
- `/init --new` — run the guided setup for CLAUDE.md, skills, and hooks

## What to do

1. Recall and follow the **`init`** skill (`skills/init/SKILL.md`).
2. Choose the variant (Step 1 of the skill) from the arguments and environment.
3. Load the matching prompt from
   `${CLAUDE_PLUGIN_ROOT}/assets/prompts/init-{classic,new}.md` and execute it
   against this repository.
4. Deliver the files you wrote and the key points captured in each; remind the
   user they're a starting point to review and can re-run `/init` to refresh.

$ARGUMENTS
