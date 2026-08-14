---
name: design
description: Invoked by review-beta:start, which routes every review request and decides which aspects apply — use that entry skill first; this is one of the aspects it delegates to. Reviews a change for design-health regressions and returns a structured findings report with a verdict, running scripts/probe-design.sh — clone detectors, architecture contracts, dead-export analysers, API-diff tools — before spending any judgement. Covers the taxonomy's 13 design dimensions — speculative generality, wrong abstraction, duplication, public surface minimality, backward and data-contract compatibility, deprecation and migration, layering and dependency direction, cohesion, hidden global state, testability seams, configuration surface, and new third-party dependencies. NOT for whether the code works (review-beta:correctness) or whether it matches house convention (review-beta:org-fit).
context: fork
background: false
allowed-tools: Read, Grep, Glob, Bash(${CLAUDE_SKILL_DIR}/scripts/probe-design.sh:*)
---

# review-beta:design

Review the change at $ARGUMENTS for design-health regressions and return the findings report
defined in §5. With no `$ARGUMENTS`, review the working-tree diff against the default branch.

This is one aspect subskill of a multi-aspect review. The parent orchestrator (`review-beta:start`)
collects this report alongside the other five aspects and synthesizes them, so the report is the
whole product: **the parent sees only the return value, never any of this reasoning.**

This is the one aspect whose value is genuine judgement, which is exactly why §3's calibration rule
is not optional. `background: false` keeps the findings inside the parent's turn.

---

## 1. Run the probe first — always

```
${CLAUDE_SKILL_DIR}/scripts/probe-design.sh [--base <ref>] [<repo-root>]
```

It runs jscpd, dependency-cruiser, import-linter, knip, vulture, cargo-semver-checks, buf breaking,
oasdiff, gocognit and radon where each is installed, emitting
`SEVERITY|FILE|LINE|DIMENSION|MESSAGE` plus `#`-prefixed metadata. `--list` prints the tool table.

Fields are `|`-separated; a literal pipe inside FILE or MESSAGE arrives escaped as `\|`, so the field count is always five.

| Rule                          | Consequence                                                                                                     |
| :---------------------------- | :-------------------------------------------------------------------------------------------------------------- |
| Probe, then battery           | If `.review/battery.sarif` exists, adjudicate its partitioned results rather than re-running a detector         |
| No tool, no finding           | A dimension with no detector is **unavailable** and produces zero findings — say so in §5                       |
| Judge over flagged units only | Cohesion, wrong-abstraction and duplication findings are adjudicated **only** over units a tool already flagged |

**Output-format coverage.** The probe parses each tool's own stdout, so a filter that does not match its tool is a silent zero-findings bug rather than a crash. The shapes emitted by `jscpd`, `vulture` and `semgrep` (`--vim`) were verified against real output from those tools; the ones with a captured fixture are pinned and asserted in [`tests/run-probe-tests.sh`](../../tests/run-probe-tests.sh). The shapes assumed for `knip`, `depcruise`, `lint-imports`, `cargo-semver-checks`, `buf`, `oasdiff`, `gocognit`, `radon` are **unverified** — those tools could not be run here. Treat an unexpected zero from one of them as suspect, and confirm by running it directly before reporting the dimension clean.

The third rule is what separates this aspect from taste. Complexity and duplication metrics are
cheap and objective; opening a file to decide it "feels large" is neither.

---

## 2. Adjudicate only the residue

The dimension table — question, ceiling, tier, residual — is in
[references/dimensions.md](references/dimensions.md). The residues that recur:

| Dimension                             | The tool decided                                | You decide                                                           |
| :------------------------------------ | :---------------------------------------------- | :------------------------------------------------------------------- |
| `design-yagni-speculative-generality` | Variation points with zero inhabitants          | The concrete inhabitant count, and where a second would live         |
| `design-wrong-abstraction`            | Boolean-at-every-call-site, branch-only params  | Whether the parameter names a real axis of variation                 |
| `design-duplication`                  | Clone pairs above the project threshold         | Which copy is canonical, and whether the clone is the cheaper option |
| `design-api-surface-minimality`       | Exports with no external consumer               | Whether an unreferenced export is a deliberate extension point       |
| `design-backward-compatibility`       | Contract diff vs the declared version           | Whether an observable-but-undeclared behaviour has a real dependent  |
| `design-deprecation-migration`        | Annotation, marker age, remaining-caller census | Whether window and migration owner are adequate to that census       |
| `design-cohesion-responsibility`      | God-class and complexity deltas                 | The proposed split boundary — over flagged units only                |
| `design-testability-seams`            | Constructor work, static IO, service locators   | Whether a seam is worth its indirection here                         |

`design-dependency-direction` is decided outright where a contract file exists; judgement applies
only where none does — and then the question is whether the boundary is real at all.

---

## 3. Rate every finding, and stay two-sided

| Severity | Test                                                                         |
| :------- | :--------------------------------------------------------------------------- |
| blocker  | Would you page someone at 03:00 for this, or owe an external party notice?   |
| major    | More expensive to fix in three months than today, and you can name who pays? |
| minor    | A tool output or counted metric backs it, and the fix is under ~15 minutes?  |
| nit      | A reasonable engineer could disagree and still be right?                     |

The calibration rules that keep design findings honest:

- **Cite a principle and an observable signal, never a preference.** A finding with neither is a nit
  by definition, and a nit that recurs is a tooling gap — file the lint rule instead.
- **Claim a health regression, not an unrealised improvement.** "This could be more elegant" is not
  a finding; "this diff adds a third copy of the retry policy" is.
- Two pairs are deliberately opposed: `design-yagni-speculative-generality` ↔
  `design-testability-seams`, and `design-wrong-abstraction` ↔ `design-duplication`. If your report
  only ever fires on one side of a pair, you are miscalibrated — re-read the opposing dimension
  before returning.
- Only `design-backward-compatibility` and `design-dependency-direction` carry blocker ceilings.
- Cap at **3 non-blocker findings**, blockers exempt.

---

## 4. Not this aspect's job

From the taxonomy's de-duplication ledger:

| Subject                                                      | Owner                                                                                                |
| :----------------------------------------------------------- | :--------------------------------------------------------------------------------------------------- |
| Whether the code is correct at all                           | `review-beta:correctness`                                                                            |
| Interface shape against a threshold the repo configured      | `review-beta:org-fit` (`org-fit-interface-convention-conformance`)                                   |
| Whether our own versions coexist safely during rollout       | `review-beta:process` (`process-deploy-sequencing`)                                                  |
| Whether a dependency is vulnerable, unmaintained or impostor | `review-beta:security` — this aspect owns only whether it is worth its carrying cost                 |
| Prose duplication in docs, and stale docs                    | `review-beta:docs` — except that duplication of a _fact_ is `design-duplication` with `medium: fact` |
| Dead/unreferenced code, import cycles                        | Hard gates — the run aborts, they are not findings                                                   |

`design-backward-compatibility` owns breaking a published code/RPC/HTTP contract;
`design-data-contract-compatibility` owns an emitted event, log, metric or export consumed outside
the repo. Those two are distinct dimensions, not duplicates of each other.

---

## 5. Return contract

Return this and nothing else. No preamble, no narration.

```markdown
## review-beta:design

VERDICT: PASS | FAIL
SCOPE: <what was reviewed — diff range or paths>
COUNTS: blocker=<n> major=<n> minor=<n> nit=<n> (tool=<n> judged=<n>)

| Sev     | Location             | Dimension                     | Problem                                                                                    | Remedy                                                  | Confidence |
| :------ | :------------------- | :---------------------------- | :----------------------------------------------------------------------------------------- | :------------------------------------------------------ | :--------- |
| blocker | proto/order.proto:22 | design-backward-compatibility | `buf breaking` reports field 4 removed; the contract promises removal only on a major bump | Reserve field 4 and its name, or ship the removal in v2 | high       |

UNAVAILABLE:

- <dimension> — <detector that was missing or deferred>
```

- `VERDICT: FAIL` iff at least one **blocker** survives.
- Every row cites a taxonomy dimension id — that is how the parent de-duplicates aspects.
- Every row names its signal: the tool output, the threshold crossed, or the counted metric.
- `Location` is `file:line`; line `0` only when a finding genuinely has no line.
- `Confidence` is `high` | `medium` | `low`; a `low` row states what would confirm it.
- One row per finding, sorted blocker → major → minor → nit.
- With no findings, emit the header block with `VERDICT: PASS`, zeroed counts, and `NO FINDINGS`.
- Omit `UNAVAILABLE` when every dimension had its detector.
- Where a judged finding could have been a rule, append `AUTOMATION: <the rule to encode>`.

---

## 6. Related

| Skill                     | Relationship                                                    |
| :------------------------ | :-------------------------------------------------------------- |
| `review-beta:start`       | The orchestrator that invokes this aspect and merges its report |
| `review-beta:org-fit`     | Owns conformance to conventions the repo actually declared      |
| `review-beta:correctness` | Owns whether the design, as written, produces the wrong answer  |
