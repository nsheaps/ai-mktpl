---
name: docs
description: Invoked by review-beta:start, which routes every review request and decides which aspects apply — use that entry skill first; this is one of the aspects it delegates to. Reviews documentation changes and returns a structured findings report with a verdict, running scripts/probe-docs.sh — lychee, markdownlint, Vale, cspell, doctest runners — before spending any judgement. Covers the taxonomy's 18 docs dimensions — entry-point completeness, executable quickstarts, example correctness, reference coverage, doc/code synchrony, link and URL integrity, version applicability, translation drift, ownership, presentation, terminology, claim substantiation, changelog quality, authored-source accessibility, message quality, and decision rationale. NOT for whether the described code is correct (review-beta:correctness) or whether agent configuration is well built (review-beta:agentic-configuration).
context: fork
background: false
allowed-tools: Read, Grep, Glob, Bash(${CLAUDE_SKILL_DIR}/scripts/probe-docs.sh:*)
---

# review-beta:docs

Review the documentation touched by $ARGUMENTS and return the findings report defined in §5. With
no `$ARGUMENTS`, review the working-tree diff against the default branch.

This is one aspect subskill of a multi-aspect review. The parent orchestrator (`review-beta:start`)
collects this report alongside the other five aspects and synthesizes them, so the report is the
whole product: **the parent sees only the return value, never any of this reasoning.**

This family is the most automatable of the six: eight of its eighteen dimensions are `agent: skip`,
decided outright by a tool. Your licence here is correspondingly narrow — see §3.

---

## 1. Run the probe first — always

```
${CLAUDE_SKILL_DIR}/scripts/probe-docs.sh [--base <ref>] [<repo-root>]
```

It runs lychee, markdownlint-cli2, Vale, cspell, prettier, the doctest runners and the site builder
where each is installed, emitting `SEVERITY|FILE|LINE|DIMENSION|MESSAGE` plus `#`-prefixed
metadata. `--list` prints the tool table without running anything.

Fields are `|`-separated; a literal pipe inside FILE or MESSAGE arrives escaped as `\|`, so the field count is always five.

| Rule                  | Consequence                                                                                           |
| :-------------------- | :---------------------------------------------------------------------------------------------------- |
| Probe, then battery   | If `.review/battery.sarif` exists, adjudicate its partitioned results rather than re-running a linter |
| No tool, no finding   | A dimension with no linter is **unavailable** and produces zero findings — say so in §5               |
| Relay, don't re-judge | `agent: skip` dimensions are rendered from tool output verbatim: a broken link is a broken link       |

**Output-format coverage.** The probe parses each tool's own stdout, so a filter that does not match its tool is a silent zero-findings bug rather than a crash. The shapes emitted by `lychee`, `markdownlint-cli2`, `cspell` and `prettier` were verified against real output from those tools; the ones with a captured fixture are pinned and asserted in [`tests/run-probe-tests.sh`](../../tests/run-probe-tests.sh). The shapes assumed for `vale`, `interrogate`, `mkdocs`, `pytest --doctest-modules`, `cargo test --doc` are **unverified** — those tools could not be run here. Treat an unexpected zero from one of them as suspect, and confirm by running it directly before reporting the dimension clean.

The `agent: skip` set here: `docs-entry-point-completeness`, `docs-getting-started-executable`,
`docs-example-correctness`, `docs-link-graph-integrity`, `docs-url-stability-and-redirects`,
`docs-translation-sync`, `docs-ownership-and-freshness`, `docs-presentation`.

---

## 2. Adjudicate only the residue

The dimension table — question, ceiling, tier, residual — is in
[references/dimensions.md](references/dimensions.md). The residues that recur:

| Dimension                           | The tool decided                                 | You decide                                                  |
| :---------------------------------- | :----------------------------------------------- | :---------------------------------------------------------- |
| `docs-code-sync`                    | Doc-map coupling, dangling identifiers           | Whether the prose still describes what the code now does    |
| `docs-api-reference-coverage`       | Undocumented exported symbols                    | Whether the docstring says anything a signature does not    |
| `docs-terminology-consistency`      | Vale substitution and existence hits             | Whether two terms are genuinely one concept                 |
| `docs-claim-substantiation`         | Unlinked security/performance claims             | Whether the cited source actually supports the claim        |
| `docs-changelog-quality`            | Structure, categories, dates, commit cross-check | Whether a user could decide from it alone to upgrade        |
| `docs-accessibility`                | Missing alt text, bare URLs, heading order       | Whether the alt text conveys the same information           |
| `docs-user-facing-message-quality`  | Message-string lint hits                         | Whether the message says what happened and what to do next  |
| `docs-decision-rationale`           | ADR section, status and numbering lint           | Whether the _why_ — options rejected — is actually recorded |
| `docs-versioning-and-applicability` | Front-matter `applies_to` presence               | Whether the stated version range matches the change         |

`docs-placement` is inert unless the repo declares a docs taxonomy (`type:` front-matter or a
Diátaxis directory split). If it does not, report the dimension unavailable rather than inventing
a taxonomy to judge against.

---

## 3. Rate every finding, and stay inside the licence

| Severity | Test                                                                         |
| :------- | :--------------------------------------------------------------------------- |
| blocker  | Would you page someone at 03:00 for this, or owe an external party notice?   |
| major    | More expensive to fix in three months than today, and you can name who pays? |
| minor    | A tool output or counted metric backs it, and the fix is under ~15 minutes?  |
| nit      | A reasonable engineer could disagree and still be right?                     |

- **No dimension in this family carries a blocker ceiling.** A stale README is not a blocker;
  ceiling inflation is how a reviewer becomes something people route around. The verdict for this
  aspect is therefore normally PASS even with findings — see §5.
- Cap at **3 non-blocker findings** for this family, and at most **3 across docs + process +
  org-fit combined** when all three run in one review. Rank by severity then signal strength.
- `docs-presentation` has a `nit` ceiling and is tool-output only. Never author a presentation
  finding by hand.

---

## 4. Not this aspect's job

From the taxonomy's de-duplication ledger:

| Subject                                                         | Owner                                                                                              |
| :-------------------------------------------------------------- | :------------------------------------------------------------------------------------------------- |
| Correctness of the code the docs describe                       | `review-beta:correctness`                                                                          |
| A secret pasted into a doc example                              | `review-beta:security` (`sec-secret-material-exposure`)                                            |
| Duplication of an authoritative _fact_ across documents         | `review-beta:design` (`design-duplication`, `medium: fact`)                                        |
| The deprecation window, caller census and migration owner       | `review-beta:design` (`design-deprecation-migration`) — this aspect owns only the notice artifacts |
| Whether behaviour changed and the prose did not, in _org_ terms | `docs-code-sync` here; `org-fit-documentation-sync` was merged into it                             |
| Whether a SKILL.md is well built                                | `review-beta:agentic-configuration`                                                                |
| Rendered-UI accessibility                                       | `review-beta:org-fit` (the `org-fit-a11y-*` set) — this aspect owns authored doc source only       |

---

## 5. Return contract

Return this and nothing else. No preamble, no narration.

```markdown
## review-beta:docs

VERDICT: PASS | FAIL
SCOPE: <what was reviewed — diff range or paths>
COUNTS: blocker=<n> major=<n> minor=<n> nit=<n> (tool=<n> judged=<n>)

| Sev   | Location     | Dimension                       | Problem                                                                                         | Remedy                                                                       | Confidence |
| :---- | :----------- | :------------------------------ | :---------------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------- | :--------- |
| major | README.md:31 | docs-getting-started-executable | Quickstart calls `app init`, removed in this diff; a stranger pasting it gets `unknown command` | Update the quickstart to `app setup`, and add it to the container smoke test | high       |

UNAVAILABLE:

- <dimension> — <linter that was missing, or the config the dimension needs>
```

- `VERDICT: FAIL` iff at least one **blocker** survives. No docs dimension can produce one, so this
  aspect returns FAIL only if a finding was re-routed here from a blocker-ceiling dimension —
  which means it belongs to another aspect and should be routed instead.
- Every row cites a taxonomy dimension id — that is how the parent de-duplicates aspects.
- `Location` is `file:line`; line `0` only when a finding genuinely has no line.
- `Confidence` is `high` | `medium` | `low`; a `low` row states what would confirm it.
- One row per finding, sorted blocker → major → minor → nit.
- With no findings, emit the header block with `VERDICT: PASS`, zeroed counts, and `NO FINDINGS`.
- Omit `UNAVAILABLE` when every dimension had its tool.
- Where a judged finding could have been a rule, append `AUTOMATION: <the rule to encode>`.

---

## 6. Related

| Skill                               | Relationship                                                     |
| :---------------------------------- | :--------------------------------------------------------------- |
| `review-beta:start`                 | The orchestrator that invokes this aspect and merges its report  |
| `review-beta:agentic-configuration` | Reviews SKILL.md authoring specifically; this aspect skips those |
| `review-beta:design`                | Owns fact duplication and the deprecation window                 |
