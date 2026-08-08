---
name: team-onboarding
description: Generate an ONBOARDING.md guide for teammates new to Claude Code from how you've actually used it in this repo. Scans your local transcripts, classifies your work, and co-authors an interactive guide.
argument-hint: "[--days N]"
allowed-tools: Read, Write, Edit, Bash(node:*), Bash(ls:*), Bash(git config:*), Bash(git remote:*), Bash(mise:*)
---

# Team Onboarding

Scan your local session transcripts for how you've used Claude Code in this repo
over a recent window, classify your work into task types, and co-author an
`ONBOARDING.md` guide that teammates can paste into Claude Code for a guided
setup tour.

The driving prompt and guide template are the built-in's own, verbatim.

Invoke the **`team-onboarding`** skill and follow it end to end.

## Arguments

**Format:** `[--days N]`

| Argument      | Meaning                                                            |
| ------------- | ------------------------------------------------------------------ |
| `--days N`    | Window in days to scan (alias `--window N`; default **30**).       |
| trailing text | Extra context you may use while co-authoring the guide (optional). |

**Examples:**

- `/team-onboarding` — scan the last 30 days and build the guide
- `/team-onboarding --days 90` — widen the scan window to 90 days

## What to do

1. Recall and follow the **`team-onboarding`** skill
   (`skills/team-onboarding/SKILL.md`).
2. Resolve the window from `--days`/`--window` (default 30).
3. Run `node ${CLAUDE_PLUGIN_ROOT}/scripts/collect-onboarding-data.mjs --days <N>`
   from this repo and capture the `usageData` JSON on stdout. If it reports
   `no_project_dir`, tell the user this directory has no Claude Code history and
   stop.
4. Load `${CLAUDE_PLUGIN_ROOT}/assets/prompts/team-onboarding.md`, substitute
   `{{WINDOW_DAYS}}`, `{{USAGE_DATA}}`, and `{{GUIDE_TEMPLATE}}` (from
   `assets/prompts/onboarding-guide-template.md`), and run the flow exactly:
   emit the acknowledgment line first, classify sessions, write `ONBOARDING.md`,
   render it, then ask the three Review questions and finalize.
5. Saving to `ONBOARDING.md` is the deliverable. The built-in's internal share
   tool (server-gated `ShareOnboardingGuide`) is not available outside the CLI —
   use the manual close from the skill.

$ARGUMENTS
