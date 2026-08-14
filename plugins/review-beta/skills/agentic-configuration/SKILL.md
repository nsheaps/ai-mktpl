---
name: agentic-configuration
description: Invoked by review-beta:start, which routes every review request and decides which aspects apply — use that entry skill first; this is one of the aspects it delegates to. Reviews whether agent configuration is well built — skills, plugin manifests, hook wiring, agents, commands and the MCP config they declare — covering frontmatter conformance, description trigger accuracy, length budgets, progressive-disclosure layout, fork return contracts, manifest required fields, and hook events that silently never fire. Runs scripts/check-skill.sh and scripts/check-plugin.sh for every mechanical check before spending any judgement. Returns a structured findings report with a pass/fail verdict. NOT for judging whether the subject matter a skill teaches is factually correct, and NOT for general code review of the scripts a plugin bundles (review-beta:correctness owns that).
context: fork
background: false
compatibility: "Requires Claude Code v2.1.218 or later. Earlier versions ignore `background: false`, so this skill forks into the background and returns nothing to the caller — which reads as a clean review rather than an error."
allowed-tools: Read, Grep, Glob, Bash(${CLAUDE_SKILL_DIR}/scripts/check-skill.sh:*), Bash(${CLAUDE_SKILL_DIR}/scripts/check-plugin.sh:*)
---

# review-beta:agentic-configuration

Review the agent configuration at $ARGUMENTS and return the findings report defined in §5. If
`$ARGUMENTS` is empty, review every artifact under the current working directory.

"Agent configuration" is everything that tells an agent how to behave, not what the product does:

| Artifact               | Where it lives                       | Checked by        |
| :--------------------- | :----------------------------------- | :---------------- |
| Skill                  | `**/SKILL.md`                        | `check-skill.sh`  |
| Plugin manifest        | `.claude-plugin/plugin.json`         | `check-plugin.sh` |
| Hook wiring            | `hooks/hooks.json` + its scripts     | `check-plugin.sh` |
| Subagent               | `agents/*.md`                        | `check-plugin.sh` |
| Slash command          | `commands/*.md`                      | `check-plugin.sh` |
| MCP server declaration | `.mcp.json`, `mcpServers` in configs | judged only (§3)  |
| Settings / permissions | `settings*.json`                     | judged only (§3)  |

This is one aspect subskill of a multi-aspect review. A parent orchestrator
(`review-beta:start`) collects this report alongside other aspects and synthesizes them, so the
report is the whole product: **the parent sees only the return value, never any of this
reasoning.** Anything not in the return value is lost.

`background: false` is deliberate — the parent needs the findings inside its own turn, and a
backgrounded fork gets a narrower tool set than the Bash-plus-Read work below requires. It needs
Claude Code v2.1.218+; on older versions the fork blocks anyway, which is the desired behaviour.

---

## 1. Run both scripts first — always

They decide every mechanically decidable criterion. Run them before reading anything, and never
re-derive by hand what they already reported:

```
${CLAUDE_SKILL_DIR}/scripts/check-skill.sh  <path-to-SKILL.md-or-directory>
${CLAUDE_SKILL_DIR}/scripts/check-plugin.sh <path-to-plugin-root-or-artifact>
```

**Their directory semantics differ, so the same path is not always right for both.**
`check-skill.sh` recurses and finds every `SKILL.md` beneath the path. `check-plugin.sh` treats a
directory as exactly one plugin root and does not recurse — so a parent of several plugins needs
`plugins/*/`, not `plugins/`. Handing it a path with no recognized artifact is not a pass: it
reports `verdict=EMPTY` and exits 2, which is a usage error to fix rather than a result to report.

Add `--portable` to `check-skill.sh` when the skill may be uploaded or packaged to claude.ai —
that narrows the frontmatter whitelist to the six-field Agent Skills spec.

Both emit the same shape, one finding per line — `SEVERITY|FILE|LINE|CHECK_ID|MESSAGE` — plus
`#`-prefixed summary lines, and both exit 1 when any P0 exists. Concatenate the two streams and
adjudicate one list.

Two reasons this ordering matters. Scripted checks are deterministic and free, so a review that
re-reads a file to count its lines burns tokens for a worse answer. And their findings already
carry file, line, and a stable check ID, which is most of what the report needs — the work left is
translating each one into a remedy and adding what a script genuinely cannot see.

| Prefix | Owner             | Covers                                                    |
| :----- | :---------------- | :-------------------------------------------------------- |
| `SK`   | `check-skill.sh`  | SKILL.md frontmatter, budgets, layout, fork wiring        |
| `PL`   | `check-plugin.sh` | `plugin.json` fields, name/dir match, README, hooks field |
| `HK`   | `check-plugin.sh` | `hooks.json` validity and script wiring                   |
| `AG`   | `check-plugin.sh` | `agents/*.md` frontmatter and name/filename match         |
| `CM`   | `check-plugin.sh` | `commands/*.md` frontmatter                               |

The skill check catalogue, with the heuristics whose limits need a human eye, is in
[references/authoring-standard.md](references/authoring-standard.md) §6. Read that file when a
finding needs an explanation of _why_ the rule exists, or when judging §2 below. Every `PL`/`HK`/
`AG`/`CM` check names its source rule in the finding message, so a disputed one is settled by
reading that rule rather than by argument.

**A missing tool is not a clean result.** `check-plugin.sh` needs `jq`; without it the manifest
and hook checks emit `PL000`/`HK000` and produce zero findings. That is **unavailable**, not
passing — report it in §5's `UNVERIFIED` block rather than letting a silent zero read as coverage.

---

## 2. Then judge only what the scripts cannot decide

Read the SKILL.md body once, and each reference file the body links to. Assess exactly these,
skipping any a script already covered:

| #   | Sev | Judgement                                                                      |
| :-- | :-- | :----------------------------------------------------------------------------- |
| J1  | P0  | Description names concrete trigger phrases a real user would type              |
| J2  | P0  | Description separates itself from competing sibling skills                     |
| J3  | P0  | Key use case survives truncation to 200 chars                                  |
| J4  | P0  | A `context: fork` skill's return contract is specific enough to consume        |
| J5  | P1  | Body earns its recurring per-session token cost                                |
| J6  | P1  | Degrees of freedom match task fragility                                        |
| J7  | P1  | Load-bearing content is front-loaded (compaction keeps the first 5,000 tokens) |
| J8  | P1  | This is genuinely a skill, not a rule or a subagent                            |
| J9  | P1  | One term per concept, no synonym drift                                         |
| J10 | P1  | Reference splits map to distinct user intents                                  |
| J11 | P2  | Side-effecting workflows set `disable-model-invocation: true`                  |
| J12 | P2  | `allowed-tools` is minimal for the blast radius                                |

Full wording of each, and the question to ask, is in
[references/authoring-standard.md](references/authoring-standard.md) §7.

Two disciplines keep this half honest. Quote the evidence — a J-finding without a quoted line or
a named competing skill is an opinion, and the parent cannot act on it. And when a check in §6 of
the reference is marked as a heuristic (SK012, SK018, SK022), confirm or overturn the script's
call by reading before it reaches the report; a false positive that survives into the report costs
the parent more than the check saved.

---

## 3. Artifacts with no mechanical check

MCP server declarations and `settings*.json` have no script behind them yet. Judge them only
against what is written down, cite the rule, and mark the finding `Confidence: low` — a judged
finding with no tool behind it is the kind this family is most often wrong about:

| Judgement                                                                       | Sev |
| :------------------------------------------------------------------------------ | :-- |
| An MCP server is declared with secrets inline rather than injected              | P0  |
| A declared MCP server's command is not resolvable from the plugin root          | P1  |
| `settings*.json` grants a permission wider than the artifact needs              | P1  |
| Plugin settings keys are not camelCase (`.claude/rules/settings-key-naming.md`) | P2  |

---

## 4. Do not report these as defects

- Anything listed in [references/authoring-standard.md](references/authoring-standard.md) §8 as unverified. Report it as unverified, with what would settle it.
- The org `@../../docs/excerpts/*.md` include convention. It is house style, not a defect, though a broken include path is a real SK012 finding.
- A hook script that is not executable but is invoked through an interpreter (`bash <path>`). Mode 0644 is fine there; `check-plugin.sh` deliberately does not flag it.
- Style preferences with no rule behind them. Every finding cites a check ID or a judgement ID (J1–J12).
- Content correctness of the domain a skill teaches. That is another aspect's job.

---

## 5. Return contract

Return this and nothing else. No preamble, no narration of the process, no restating the standard.

```markdown
## review-beta:agentic-configuration

VERDICT: PASS | FAIL
SCOPE: <n> artifact(s) reviewed — <path or paths>
COUNTS: P0=<n> P1=<n> P2=<n> (scripted=<n> judged=<n>)

| Sev | Location             | Check | Problem                                           | Remedy                         |
| :-- | :------------------- | :---- | :------------------------------------------------ | :----------------------------- |
| P0  | path/to/SKILL.md:12  | SK009 | `version:` is not a frontmatter field             | Move it under `metadata:`      |
| P1  | path/to/hooks.json:8 | HK003 | `command` references a script that is not on disk | Add the script or fix the path |

UNVERIFIED:

- <claim that could not be settled, and what would settle it — including any check that reported UNAVAILABLE>
```

Rules that make the report usable:

- `VERDICT: FAIL` iff at least one P0 finding exists. Nothing else changes the verdict.
- Every row cites a check ID (`SK`/`PL`/`HK`/`AG`/`CM`) or a judgement ID (J1–J12) — that is how
  the parent de-duplicates this aspect against the others.
- `Location` is `file:line`. Use line `0` only when a finding genuinely has no line, such as an
  unreferenced bundled file.
- One row per finding, sorted P0 → P1 → P2. Do not collapse repeats across files: the parent
  needs each location.
- Remedy is the concrete edit to make, not a restatement of the problem.
- With no findings, emit the header block with `VERDICT: PASS`, `COUNTS: P0=0 P1=0 P2=0`, and the
  literal line `NO FINDINGS` in place of the table.
- Omit the `UNVERIFIED` section when it would be empty.

---

## 6. Related

| Skill                       | Relationship                                                               |
| :-------------------------- | :------------------------------------------------------------------------- |
| `review-beta:start`         | The orchestrator that invokes this skill and merges its report with others |
| `review-beta:docs`          | Owns the prose quality of any docs a plugin ships, not its wiring          |
| `review-beta:correctness`   | Owns the behaviour of the scripts a plugin bundles                         |
| `skill-creator` (Anthropic) | Authoring and eval-loop guidance; this skill reviews, it does not author   |
