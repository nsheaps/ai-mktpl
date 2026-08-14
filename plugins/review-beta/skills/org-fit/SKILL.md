---
name: org-fit
description: Invoked by review-beta:start, which routes every review request and decides which aspects apply — use that entry skill first; this is one of the aspects it delegates to. Reviews whether a change fits the organization it lands in, and returns a structured findings report with a verdict, running scripts/probe-org-fit.sh — the repo's own lint task, editorconfig-checker, shellcheck, syncpack, generation drift — before spending any judgement. Covers the taxonomy's 16 org-fit dimensions — reinvented shared capabilities, copy-pasted CI, golden-path divergence, generated-artifact drift, dependency version divergence, the repo's own written rules, interface conventions, the accessibility automated scanning cannot see, i18n, declared performance budgets, platform assumptions, portability gaps, and environment parity. NOT for intrinsic design quality (review-beta:design) or release process (review-beta:process).
context: fork
background: false
compatibility: "Requires Claude Code v2.1.218 or later. Earlier versions ignore `background: false`, so this skill forks into the background and returns nothing to the caller — which reads as a clean review rather than an error."
allowed-tools: Read, Grep, Glob, Bash(${CLAUDE_SKILL_DIR}/scripts/probe-org-fit.sh:*)
---

# review-beta:org-fit

Review the change at $ARGUMENTS for fit with the organization's declared assets, rules and
conventions, and return the findings report defined in §5. With no `$ARGUMENTS`, review the
working-tree diff against the default branch.

This is one aspect subskill of a multi-aspect review. The parent orchestrator (`review-beta:start`)
collects this report alongside the other five aspects and synthesizes them, so the report is the
whole product: **the parent sees only the return value, never any of this reasoning.**

Every dimension here rests on something the org or repo **already declared**. Where nothing is
declared, the dimension is unavailable — not an invitation to supply a convention.

---

## 1. Run the probe first — always

```
${CLAUDE_SKILL_DIR}/scripts/probe-org-fit.sh [--base <ref>] [<repo-root>]
```

It runs the repo's own `lint` task where one exists, plus editorconfig-checker, prettier, eslint,
`buf lint`, syncpack, `go mod tidy -diff`, shellcheck and a case-collision check, emitting
`SEVERITY|FILE|LINE|DIMENSION|MESSAGE` plus `#`-prefixed metadata. `--list` prints the tool table.

Fields are `|`-separated; a literal pipe inside FILE or MESSAGE arrives escaped as `\|`, so the field count is always five.

| Rule                         | Consequence                                                                                                             |
| :--------------------------- | :---------------------------------------------------------------------------------------------------------------------- |
| Probe, then battery          | If `.review/battery.sarif` exists, adjudicate its partitioned results rather than re-running a linter                   |
| No declaration, no dimension | With no blessed-capability registry, budget config, i18n corpus or rendered UI, the matching dimensions are unavailable |
| No tool, no finding          | A dimension whose check is missing produces zero findings — say so in §5                                                |

**Output-format coverage.** The probe parses each tool's own stdout, so a filter that does not match its tool is a silent zero-findings bug rather than a crash. The shapes emitted by `prettier` and the git-derived checks this probe computes itself were verified against real output from those tools; the ones with a captured fixture are pinned and asserted in [`tests/run-probe-tests.sh`](../../tests/run-probe-tests.sh). The shapes assumed for the repo `lint` task passthrough, `editorconfig-checker`, `eslint`, `buf`, `syncpack`, `go mod tidy -diff`, `shellcheck` are **unverified** — those tools could not be run here. Treat an unexpected zero from one of them as suspect, and confirm by running it directly before reporting the dimension clean.

The capability probe disables these outright: `org-fit-i18n` with no `locales/`, `messages.*`,
`*.po` or i18n framework; the four `org-fit-a11y-*` dimensions with no rendered UI surface;
`org-fit-performance-budget-regression` with no declared budget config.

Formatter, linter and `.editorconfig` conformance is a **hard gate**, not a dimension here: if the
repo's own lint task fails, the run aborts with "fix the failing gate first" rather than producing
findings.

---

## 2. Adjudicate only the residue

The dimension table — question, ceiling, scope, tier, residual — is in
[references/dimensions.md](references/dimensions.md). The residues that recur:

| Dimension                                  | The tool decided                                 | You decide                                                   |
| :----------------------------------------- | :----------------------------------------------- | :----------------------------------------------------------- |
| `org-fit-shared-library-reuse`             | Hand-rolled shapes matching blessed capabilities | Whether the blessed library actually covers this use         |
| `org-fit-golden-path-divergence`           | Policy failures over rendered manifests          | Whether the divergence is a justified exception              |
| `org-fit-dependency-version-divergence`    | Version mismatches across the workspace          | Which version the repo should converge on                    |
| `org-fit-repo-stated-rules`                | Rules index and dangling `enforced-by` refs      | Whether the diff actually breaks the rule as written         |
| `org-fit-interface-convention-conformance` | API-linter and parameter-count violations        | Whether a violation is misuse-prone in practice              |
| `org-fit-a11y-semantics-and-keyboard`      | jsx-a11y hits, tab-order traversal               | Whether the announced name and role match the visible intent |
| `org-fit-i18n`                             | Literal strings, locale-less formatting          | Whether the string is genuinely user-facing                  |
| `org-fit-platform-assumption-leakage`      | GNU-only flags, hardcoded paths, case collisions | Whether the assumption is inside a platform-scoped file      |
| `org-fit-environment-parity`               | Service/image/version table across environments  | Whether a divergence is deliberate and bounded               |

`org-fit-ci-pipeline-reuse`, `org-fit-generated-artifact-drift`,
`org-fit-performance-budget-regression` and `org-fit-portability-matrix-gap` are `agent: skip` —
relay the tool's decision verbatim.

---

## 3. Rate every finding against the rubric

| Severity | Test                                                                         |
| :------- | :--------------------------------------------------------------------------- |
| blocker  | Would you page someone at 03:00 for this, or owe an external party notice?   |
| major    | More expensive to fix in three months than today, and you can name who pays? |
| minor    | A tool output or counted metric backs it, and the fix is under ~15 minutes?  |
| nit      | A reasonable engineer could disagree and still be right?                     |

- **No dimension in this family carries a blocker ceiling.** A hand-rolled utility is not a blocker.
- Every finding must quote the declaration it violates — the rule file, the registry entry, the
  budget config, the convention doc — with a path. A convention nobody wrote down is a nit, and a
  recurring nit is a tooling gap: recommend the lint rule instead of raising it again.
- Repo policy can raise a ceiling: where the repo declares a budget or gate as mandatory,
  `org-fit-performance-budget-regression` escalates accordingly.
- Cap at **3 non-blocker findings** for this family, and at most **3 across docs + process +
  org-fit combined** when all three run in one review.

---

## 4. Not this aspect's job

From the taxonomy's de-duplication ledger:

| Subject                                             | Owner                                                                                                                 |
| :-------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------- |
| Whether an abstraction is intrinsically wrong       | `review-beta:design`                                                                                                  |
| Whether a new dependency is worth its carrying cost | `review-beta:design` (`design-third-party-dependency`) — this aspect owns only version divergence from the org's pick |
| Whether a dependency is vulnerable or unmaintained  | `review-beta:security`                                                                                                |
| Release mechanics, merge gating, rollout            | `review-beta:process`                                                                                                 |
| Machine-detectable WCAG failures on a rendered page | Hard gate (axe/pa11y) — this aspect owns the remainder, which is most of WCAG                                         |
| Formatter, linter and `.editorconfig` conformance   | Hard gate — the run aborts, it is not a finding                                                                       |
| Accessibility of authored documentation source      | `review-beta:docs` (`docs-accessibility`)                                                                             |

`design-interface-shape` was merged into `org-fit-interface-convention-conformance`: a threshold
the repo configured is house convention and belongs here; a threshold nobody agreed to is a nit.

---

## 5. Return contract

Return this and nothing else. No preamble, no narration.

```markdown
## review-beta:org-fit

VERDICT: PASS | FAIL
SCOPE: <what was reviewed — diff range or paths>
COUNTS: blocker=<n> major=<n> minor=<n> nit=<n> (tool=<n> judged=<n>)

| Sev   | Location        | Dimension                    | Problem                                                                                                                                   | Remedy                                                                          | Confidence |
| :---- | :-------------- | :--------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------ | :--------- |
| major | src/retry.ts:12 | org-fit-shared-library-reuse | Hand-rolled exponential backoff; `@org/resilience` is listed in `.review/blessed-capabilities.yaml:8` and already handles jitter and caps | Replace with `@org/resilience` `withRetry`, or record an exception in that file | medium     |

UNAVAILABLE:

- <dimension> — <check that was missing, or the declaration the dimension needs>
```

- `VERDICT: FAIL` iff at least one **blocker** survives. No org-fit dimension can produce one, so
  this aspect returns FAIL only when a finding was re-routed here in error — route it instead.
- Every row cites a taxonomy dimension id — that is how the parent de-duplicates aspects.
- Every row quotes the declaration it violates, with a path.
- `Location` is `file:line`; line `0` only when a finding genuinely has no line.
- `Confidence` is `high` | `medium` | `low`; a `low` row states what would confirm it.
- One row per finding, sorted blocker → major → minor → nit.
- With no findings, emit the header block with `VERDICT: PASS`, zeroed counts, and `NO FINDINGS`.
- Omit `UNAVAILABLE` when every dimension had its check and its declaration.
- Where a judged finding could have been a rule, append `AUTOMATION: <the rule to encode>`.

---

## 6. Related

| Skill                | Relationship                                                                |
| :------------------- | :-------------------------------------------------------------------------- |
| `review-beta:start`  | The orchestrator that invokes this aspect and merges its report             |
| `review-beta:design` | Owns intrinsic design quality; this aspect owns conformance to declarations |
| `review-beta:docs`   | Owns authored doc source, including its accessibility                       |
