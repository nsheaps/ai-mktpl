---
name: team-onboarding
description: >
  Use this skill when the user runs /team-onboarding or asks to "create an
  onboarding guide for my team", "generate a Claude Code onboarding doc",
  "onboard new teammates to how I use Claude", or "make an ONBOARDING.md from my
  usage". Drives Claude Code's built-in `/team-onboarding` prompt, verbatim,
  against your local session transcripts for how you've used Claude Code over a
  recent window (slash commands, MCP servers, session topics) and co-authors an
  ONBOARDING.md guide teammates can paste into Claude for a guided walkthrough.
  The built-in's server-gated share step is not reproducible; saving
  ONBOARDING.md is the deliverable.
---

# Team Onboarding

Looks at how _you_ have actually used Claude Code in this repo over the last N
days and turns that into an `ONBOARDING.md` guide for teammates who are new to
Claude Code. The guide is both a document and an interactive
experience: a new teammate pastes it into Claude Code and gets a guided setup
tour.

The prompt and guide template ship verbatim in this plugin (extracted from the
CLI binary v2.1.225), alongside the data collector. The built-in's final "share
to team" step calls a server-gated internal tool (`ShareOnboardingGuide`) that is
not available outside the CLI, so this skill closes by saving the file rather
than sharing it.

## Architecture

```
/team-onboarding [--days N]
        │
        ├─ collect-onboarding-data.mjs   (scripts/)
        │     scans ~/.claude/projects/<encoded-cwd>/*.jsonl in the window,
        │     emits usageData JSON: slashCommands, mcpServers, sessionDescriptors
        │
        ├─ team-onboarding prompt         (assets/prompts/team-onboarding.md)
        │     classifies sessions into work types, drives the whole flow
        │
        └─ guide template                 (assets/prompts/onboarding-guide-template.md)
              the ONBOARDING.md skeleton the model fills in  ──▶  ONBOARDING.md
```

## Prerequisites

- `node` on `PATH` (the collector is plain ESM, no dependencies).
- Local Claude Code transcripts for this repo under
  `~/.claude/projects/<encoded-cwd>/`. If you've never used Claude Code from
  this directory, the collector reports `no_project_dir` and there's nothing to
  summarize — say so rather than inventing usage.
- Optional: `git` (used to attribute the guide to your `git config user.name`
  and to resolve the repo slug) and a project `.mcp.json` (used to annotate MCP
  servers with their URL origin). Both degrade gracefully when absent.

## Procedure

### Step 1 — Resolve the window

Parse `$ARGUMENTS` for an optional window: `--days N` / `--window N` (default
**30**). Any other trailing text is context you may use when co-authoring, but
the collector only needs the window.

### Step 2 — Collect the usage data

Run the collector from the repo you want to onboard people into:

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/collect-onboarding-data.mjs" --days <N>
```

It prints a human-readable scan summary on stderr and a single `usageData` JSON
object on stdout. Capture stdout — that JSON is the input to the prompt. If the
JSON is `{"error":"no_project_dir"}`, stop and tell the user this directory has
no Claude Code history to summarize.

> **The collector does not redact or scrub.** Each session descriptor carries
> your first user message from that session, truncated to 200 chars but
> otherwise verbatim — as do session titles and linked PR URLs. If any of your
> prompts contained secrets, customer names, or internal hostnames, they pass
> straight through into `usageData` and can end up quoted in `ONBOARDING.md`.
> Skim the collector output before the guide is shared, and drop anything
> sensitive when you write the guide in Step 4.

### Step 3 — Load the prompt and template, substitute placeholders

Read `${CLAUDE_PLUGIN_ROOT}/assets/prompts/team-onboarding.md` and follow it as
your own instructions. Substitute:

- `{{WINDOW_DAYS}}` → the window from Step 1 (both occurrences)
- `{{USAGE_DATA}}` → the exact `usageData` JSON from Step 2
- `{{GUIDE_TEMPLATE}}` → the full contents of
  `${CLAUDE_PLUGIN_ROOT}/assets/prompts/onboarding-guide-template.md`

### Step 4 — Run the flow exactly as the prompt directs

The prompt is the source of truth. In order, it requires you to:

1. **Emit the acknowledgment line first** — before any thinking, classification,
   or tool calls, output verbatim:
   > Looking at how you've used Claude over the last <N> days to put together an onboarding guide for teammates new to Claude Code.
2. **Classify each session descriptor** into one of the seven work types
   (build_feature, debug_fix, improve_quality, analyze_data, plan_design,
   prototype, write_docs) and pick the top 3–5 with rough percentages. Display
   categories in title case with spaces ("Build Feature").
3. **Gather the remaining pieces** — repos (start from `currentRepo`, check for
   sibling repo dirs), MCP servers (infer purpose/access from `name` +
   `urlOrigin`), leaving Team Tips and Get Started as TODO for now.
4. **Write `ONBOARDING.md`** from the template with real numbers. Ascii bars:
   `█` filled, `░` empty, 20 chars wide. Keep the trailing HTML-comment
   instruction block exactly as shown — it's what makes the guide interactive.
5. **Render the guide in a code block**, then a `---` rule and a `**Review**`
   heading with the three numbered follow-up questions (team name, starter task,
   team tips). After the user answers, update `ONBOARDING.md` and close with the
   exact line the prompt specifies.

## Notes on fidelity

- The collector reproduces the built-in's scan logic verbatim from the CLI
  binary (v2.1.225): the 30-day default window, the 50 MiB per-file skip, the
  200-char first-message truncation, the 60-descriptor cap sorted by
  informativeness, and the same markers/regexes for slash commands, MCP calls,
  custom titles, and PR links. The output `usageData` shape
  (`generatedBy`, `currentRepo`, `windowDays`, `sessionCount`, `slashCommands`,
  `mcpServers`, `sessionDescriptors`) matches what the built-in prompt expects.
- Both the driving prompt and the guide template ship **verbatim** from the
  binary — the acknowledgment line, the seven work-type categories, the ascii
  bar spec, the template sections, and the exact close line are unchanged.
- **The one degraded piece is sharing.** The built-in flow can offer to publish
  or share the finished guide through a Claude-Code-internal share tool (binary
  symbol `hln`). That tool is not available outside the CLI. If you would have
  called it — or if it returns `unavailable` at any point — skip the call and
  use the manual close from Step 4, item 5 instead: the guide is saved to
  `ONBOARDING.md` and the user drops it into their own team docs and channels.
  Everything else (scanning, classification, guide generation, the interactive
  walkthrough baked into the guide) works fully outside the CLI.

## Troubleshooting

| Symptom                             | Fix                                                                                          |
| ----------------------------------- | -------------------------------------------------------------------------------------------- |
| `{"error":"no_project_dir"}`        | This dir has no Claude Code history. Run from a repo you've used with Claude.                |
| `node: command not found`           | Install/activate `node`; in web sessions `eval "$(mise activate bash)"`.                     |
| Breakdown is all TODO / ~0 sessions | The window has too little history — widen it with `--days 90`, or accept the TODO.           |
| Guide creator name missing          | `git config user.name` is unset; the prompt omits the name — that's expected.                |
| Wanted it auto-shared to the team   | The internal share tool isn't available outside the CLI — save `ONBOARDING.md` and share it. |
