# Skill authoring standard (distilled)

Reference for `review-beta:agentic-configuration`. Distilled from
`/home/user/.ai-agent-jack/docs/research/skill-authoring-standard.md`, which carries the source
citations. Anything that research flags as UNVERIFIED is marked UNVERIFIED here too.

## Contents

1. [Frontmatter contract](#1-frontmatter-contract)
2. [Description rules](#2-description-rules)
3. [Length budgets](#3-length-budgets)
4. [Layout and progressive disclosure](#4-layout-and-progressive-disclosure)
5. [`context: fork`](#5-context-fork)
6. [Check ID catalogue](#6-check-id-catalogue)
7. [Judgement criteria](#7-judgement-criteria-not-scriptable)
8. [Known unverified areas](#8-known-unverified-areas)

---

## 1. Frontmatter contract

Two overlapping contracts. Claude Code accepts every spec field; the reverse is false — a Claude
Code-only key in a skill uploaded to claude.ai is a **hard error**, not a warning.

| Field                      | Contract    | Notes                                                                                     |
| :------------------------- | :---------- | :---------------------------------------------------------------------------------------- |
| `name`                     | spec, req   | 1–64 chars, `^[a-z0-9]+(-[a-z0-9]+)*$`, must equal the parent directory name              |
| `description`              | spec, req   | ≤1,024 chars. The only field in context at rest — a retrieval key, not a summary          |
| `license`                  | spec        | Accepted, no behaviour in Claude Code                                                     |
| `compatibility`            | spec        | ≤500 chars, environment requirements. Rarely needed                                       |
| `metadata`                 | spec        | map<string,string>. **This is where `version:` and `author:` belong**                     |
| `allowed-tools`            | spec (exp.) | **Grants** tools for the invoking turn only. Does not restrict anything                   |
| `when_to_use`              | Claude Code | Appended to `description`; shares the 1,536-char listing cap                              |
| `argument-hint`            | Claude Code | Autocomplete hint, display only                                                           |
| `arguments`                | Claude Code | Named positional args for `$name` substitution                                            |
| `disable-model-invocation` | Claude Code | `true` → human-only; description then not in context at all                               |
| `user-invocable`           | Claude Code | `false` → hidden from the `/` menu; description stays in context                          |
| `disallowed-tools`         | Claude Code | Removes tools while active                                                                |
| `model`                    | Claude Code | With `context: fork`, sets the forked agent's model                                       |
| `effort`                   | Claude Code | `low`\|`medium`\|`high`\|`xhigh`\|`max`                                                   |
| `context`                  | Claude Code | Only value: `fork`                                                                        |
| `agent`                    | Claude Code | Subagent type for the fork; defaults to `general-purpose`                                 |
| `background`               | Claude Code | Only with `fork`. `false` blocks the turn and keeps the full tool set. Requires v2.1.218+ |
| `hooks`                    | Claude Code | Hooks scoped to the skill's lifecycle                                                     |
| `paths`                    | Claude Code | Globs; skill auto-loads only for matching files                                           |
| `shell`                    | Claude Code | `bash` (default) \| `powershell`, for `` !`cmd` `` injection                              |

Twenty keys total. Anything else is non-conforming. The two seen in the wild:

| Key       | Why it is wrong                                                                   |
| :-------- | :-------------------------------------------------------------------------------- |
| `version` | Not a field in either contract. Nest under `metadata:`. 14 local files carry it   |
| `tools`   | That is the _subagent_ frontmatter field. On a skill the field is `allowed-tools` |

---

## 2. Description rules

| #   | Rule                                                           | Why                                                          |
| :-- | :------------------------------------------------------------- | :----------------------------------------------------------- |
| D1  | Third person always                                            | Injected into the system prompt; mixed POV hurts discovery   |
| D2  | State both what it does and when to use it                     | Claude selects from 100+ skills on this field alone          |
| D3  | Include literal trigger phrases a user would type              | Matching is lexical-ish; capability statements under-trigger |
| D4  | Add negative scope (`NOT for X`) when a sibling skill competes | Prevents over-triggering                                     |
| D5  | Key use case first                                             | The tail is truncated at the cap and by budget eviction      |
| D6  | Be pushy — Claude under-triggers skills by default             | Anthropic's own skill-creator guidance                       |
| D7  | No XML tags in `name` or `description`                         | Validation constraint                                        |

Org house form (the `debug-*` family) layers on top of D1–D7 and satisfies them:
capability sentence → `Trigger phrases — "…", "…"` → `Covers …` → `NOT for …`.

Anthropic's `plugin-dev` mandates the opener `This skill should be used when …`; the newer
published best-practices page uses the leaner `<verb-s> … Use when …`. Prefer the best-practices
form — it spends fewer of the 1,024 characters on boilerplate. Both are third person.

---

## 3. Length budgets

| Artifact                      | Budget                                             |
| :---------------------------- | :------------------------------------------------- |
| `SKILL.md` body               | <500 lines hard; ≤200 lines is the org target      |
| `SKILL.md` body               | <5,000 tokens; 1,500–2,000 words ideal             |
| `description`                 | ≤1,024 chars                                       |
| `description` + `when_to_use` | ≤1,536 chars                                       |
| Reference file                | 2,000–5,000+ words fine; add a TOC above 100 lines |

The body cost is **recurring**: invoked skill content enters the conversation and stays for the
rest of the session. Auto-compaction re-attaches only the first 5,000 tokens of each skill within
a combined 25,000-token budget, so load-bearing content goes first.

---

## 4. Layout and progressive disclosure

```
skill-name/
├── SKILL.md      # frontmatter + overview + navigation
├── references/   # loaded INTO context on demand
├── scripts/      # executed, never loaded — only output costs tokens
└── assets/       # used in output (templates, fonts, images)
```

| #   | Rule                                                                              |
| :-- | :-------------------------------------------------------------------------------- |
| S1  | Every bundled file is linked from `SKILL.md` with a note on when to read it       |
| S2  | One level deep only — `SKILL.md` → `a.md` → `b.md` is forbidden                   |
| S3  | Relative paths from the skill root, forward slashes always                        |
| S4  | Information lives in `SKILL.md` **or** a reference file, never both               |
| S5  | Descriptive filenames organised by domain                                         |
| S6  | Reference files >100 lines get a table of contents                                |
| S7  | Reference files >10k words get grep patterns in `SKILL.md`                        |
| S8  | State execute-vs-read intent: "Run `x.sh` to …" vs "See `x.sh` for the algorithm" |
| S9  | MCP tools referenced fully qualified as `ServerName:tool_name`                    |

Body style: imperative form; explain _why_ rather than stacking ALL-CAPS MUSTs; one term per
concept; no time-sensitive phrasing; one default with an escape hatch, not a menu.

---

## 5. `context: fork`

| Property      | Behaviour                                                          |
| :------------ | :----------------------------------------------------------------- |
| Context       | New isolated context; **no conversation history**                  |
| Prompt        | The rendered `SKILL.md` becomes the subagent's prompt              |
| System prompt | From the `agent:` type (default `general-purpose`)                 |
| Scheduling    | Background by default; `background: false` blocks the turn         |
| Tool set      | A backgrounded fork gets the narrower background-subagent tool set |
| Checkpoints   | A background fork's edits fall outside `/rewind`                   |

Fork only when the skill (a) states a task rather than conventions, (b) has a definable return
value, and (c) does context-heavy work relative to what it returns. A reference-style skill forked
into a subagent returns nothing useful.

The return contract is the load-bearing part: the parent never sees the fork's reasoning, so an
under-specified return value is the most common failure mode. Put the contract early and state
explicitly that the parent sees only the return value.

---

## 6. Check ID catalogue

Implemented by `../scripts/check-skill.sh`. IDs are stable; a finding cites its ID so remedies
stay linkable.

| ID    | Sev | Checks                                                                               |
| :---- | :-- | :----------------------------------------------------------------------------------- |
| SK001 | P0  | Frontmatter present (file starts with `---`)                                         |
| SK002 | P0  | Frontmatter block is closed by a second `---`                                        |
| SK003 | P0  | `name` present                                                                       |
| SK004 | P0  | `name` ≤64 chars, `^[a-z0-9]+(-[a-z0-9]+)*$`                                         |
| SK005 | P0  | `name` equals the parent directory name                                              |
| SK006 | P0  | `description` present and non-empty                                                  |
| SK007 | P0  | `description` ≤1,024 chars                                                           |
| SK008 | P0  | `description` + `when_to_use` ≤1,536 chars                                           |
| SK009 | P0  | No frontmatter key outside the 20-key contract                                       |
| SK010 | P0  | Body ≤500 lines                                                                      |
| SK011 | P1  | Body ≤200 lines (org budget)                                                         |
| SK012 | P0  | Every relative markdown link and `@`-include resolves to an existing path            |
| SK013 | P1  | Every top-level file in `references/`, `scripts/`, `assets/` is named in `SKILL.md`  |
| SK014 | P1  | `description` is third person (quoted trigger phrases exempt)                        |
| SK015 | P1  | Reference file >100 lines has a Contents section in its first 20 lines               |
| SK016 | P1  | Scripts are executable and carry a shebang                                           |
| SK017 | P1  | `agent:` / `background:` appear only alongside `context: fork`                       |
| SK018 | P1  | A `context: fork` skill states a return/output contract                              |
| SK019 | P2  | No backslash paths in references                                                     |
| SK020 | P2  | `name` contains neither `anthropic` nor `claude`                                     |
| SK021 | P1  | `--portable` only: keys ⊆ the six spec fields                                        |
| SK022 | P2  | `description` carries an explicit when-to-use or trigger clause                      |
| SK023 | P0  | No unquoted plain scalar contains `': '` — YAML fails and the whole block is dropped |

Heuristics with known limits: SK018 pattern-matches the phrases "return contract" / "output
contract" / a `Returns …` heading, so a contract stated in other words reads as a miss —
confirm by reading before reporting. SK012 skips fenced code blocks, `<placeholders>`, and
variables other than `${CLAUDE_SKILL_DIR}`, so templated paths are not verified. SK022 is a
keyword probe, not a judgement about trigger quality; J1 below is the real test.

---

## 7. Judgement criteria (not scriptable)

Only these need agent reasoning. Everything else is in §6.

| #   | Sev | Criterion                                                                   | The question to ask                                                       |
| :-- | :-- | :-------------------------------------------------------------------------- | :------------------------------------------------------------------------ |
| J1  | P0  | Description names concrete trigger phrases, not just a capability           | Among 100 skills, would this line get picked for the intended request?    |
| J2  | P0  | Description carries negative scope where a sibling competes                 | Which skill could this be confused with, and does the text separate them? |
| J3  | P0  | Key use case survives truncation                                            | Cut to 200 chars — still selectable?                                      |
| J4  | P0  | A forked skill's return contract is specific enough for a parent to consume | What exactly comes back, in what shape?                                   |
| J5  | P1  | Body earns its recurring token cost                                         | Delete this paragraph — does behaviour change?                            |
| J6  | P1  | Degrees of freedom match task fragility                                     | Narrow bridge or open field?                                              |
| J7  | P1  | Load-bearing content is front-loaded                                        | If everything after line N were dropped, would the skill still work?      |
| J8  | P1  | Correct artifact type — skill vs rule vs subagent                           | Is this an always-on invariant (rule) or a sometimes-procedure (skill)?   |
| J9  | P1  | One term per concept                                                        | Scan for synonym drift                                                    |
| J10 | P1  | Splits are by domain, so an irrelevant reference is never loaded            | Does each reference map to a distinct user intent?                        |
| J11 | P2  | Side-effecting workflows set `disable-model-invocation: true`               | Would it be bad if Claude ran this unprompted?                            |
| J12 | P2  | `allowed-tools` is minimal                                                  | What is the blast radius if this skill is malicious?                      |

---

## 8. Known unverified areas

Report these as unverified rather than as defects:

- Practical behaviour of `hooks:`, `paths:`, `shell:`, `effort:`, `arguments:`, `when_to_use:` — documented as fields, exercised by no local skill.
- Whether Claude Code warns about a well-formed but unknown frontmatter key, or ignores it silently. Only the packaging/upload hard error is confirmed.
- Whether `agent:` accepts a plugin-namespaced agent (`plugin:agent-name`).
- Whether skill→skill invocation via the `Skill` tool from inside a skill body is officially sanctioned. It works and is used locally; treat as convention, not spec.
- Whether Claude Code's loader walks the org's symlinked `.claude/skills/.org/` directory at all.
