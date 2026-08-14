---
name: process
description: Invoked by review-beta:start, which routes every review request and decides which aspects apply — use that entry skill first; this is one of the aspects it delegates to. Reviews how a change arrives and rolls out, and returns a structured findings report with a verdict, running scripts/probe-process.sh — git metadata, commitlint, actionlint, gh checks — before spending any judgement. Covers the taxonomy's 18 process dimensions — intent conformance, change size, commit hygiene, merge gating, approval authority, CI/local parity, regression tests, flaky-test policy, rollback and exposure control, deploy sequencing, lifecycle and draining, load validation, telemetry, operational readiness, release mechanics, support windows, cross-repo ordering, and recurring cost. NOT for whether the code is correct (review-beta:correctness) or fits org conventions (review-beta:org-fit).
context: fork
background: false
allowed-tools: Read, Grep, Glob, Bash(${CLAUDE_SKILL_DIR}/scripts/probe-process.sh:*)
---

# review-beta:process

Review how the change at $ARGUMENTS arrives and return the findings report defined in §5. With no
`$ARGUMENTS`, review the working-tree diff and branch state against the default branch.

This is one aspect subskill of a multi-aspect review. The parent orchestrator (`review-beta`)
collects this report alongside the other five aspects and synthesizes them, so the report is the
whole product: **the parent sees only the return value, never any of this reasoning.**

This is the cheapest family to automate — almost everything here is repo-state or diff-state, not
code semantics. Judgement is the exception, not the mode.

---

## 1. Run the probe first — always

```
${CLAUDE_SKILL_DIR}/scripts/probe-process.sh [--base <ref>] [<repo-root>]
```

It computes change size from `git diff --numstat`, checks commit subjects against Conventional
Commits, runs commitlint, actionlint, `gh pr checks` and `semantic-release --dry-run` where
available, and intersects the diff with `.review/risk-paths.yaml`. Output is
`SEVERITY|FILE|LINE|DIMENSION|MESSAGE` plus `#`-prefixed metadata; `--list` prints the tool table.

Fields are `|`-separated; a literal pipe inside FILE or MESSAGE arrives escaped as `\|`, so the field count is always five.

| Rule                     | Consequence                                                                                                 |
| :----------------------- | :---------------------------------------------------------------------------------------------------------- |
| Probe, then battery      | If `.review/battery.sarif` exists, adjudicate its partitioned results rather than re-deriving them          |
| No tool, no finding      | A dimension whose signal is missing is **unavailable** and produces zero findings — say so in §5            |
| Capability probe applies | With no deployment manifest, alerting config or migrations directory, the whole rollout cluster is disabled |

**Output-format coverage.** The probe parses each tool's own stdout, so a filter that does not match its tool is a silent zero-findings bug rather than a crash. The shapes emitted by `actionlint` and the git-derived checks this probe computes itself were verified against real output from those tools; the ones with a captured fixture are pinned and asserted in [`tests/run-probe-tests.sh`](../../tests/run-probe-tests.sh). The shapes assumed for `commitlint`, `gh pr checks`, `semantic-release` are **unverified** — those tools could not be run here. Treat an unexpected zero from one of them as suspect, and confirm by running it directly before reporting the dimension clean.

That last row matters more here than anywhere else. `process-rollback-path`,
`process-deploy-sequencing`, `process-operational-readiness`, `process-lifecycle-and-draining` and
`process-load-capacity-validation` are **disabled outright** in a repo with no deployment surface.
Asking a docs repo for its canary strategy is how a reviewer gets muted.

Dimensions scoped `repo` rather than `diff` — `process-commit-hygiene` (moot under squash-merge),
`process-merge-gating`, `process-review-authority`, `process-ci-local-parity`,
`process-flaky-test-policy`, `process-operational-readiness` — return the same verdict on every PR
until the config changes. Report them once, in a repo audit, not on each review; on a PR run,
include them only when _this diff_ changed the config they inspect.

---

## 2. Adjudicate only the residue

The dimension table — question, ceiling, scope, tier, residual — is in
[references/dimensions.md](references/dimensions.md). The residues that recur:

| Dimension                           | The tool decided                                    | You decide                                                    |
| :---------------------------------- | :-------------------------------------------------- | :------------------------------------------------------------ |
| `process-intent-conformance`        | Acceptance criteria extracted from the linked issue | Whether the diff implements exactly that, no more and no less |
| `process-change-size`               | Added/deleted lines, overlapping open PRs           | Whether a large diff genuinely decomposes                     |
| `process-merge-gating`              | Required-check set vs workflow definitions          | Whether a non-required check should be required               |
| `process-rollback-path`             | Risk-path intersection, runbook lint, flag registry | Whether the stated undo is credible for this change           |
| `process-deploy-sequencing`         | Contract diff across the rollout window             | Whether old and new versions can genuinely coexist            |
| `process-telemetry-instrumentation` | Handlers with no span, catch with no logger         | Whether the emitted signal answers the operator's question    |
| `process-defect-feedback-loop`      | New test fails on the pre-fix tree                  | Whether the automation recommendation is the right one        |
| `process-cost-impact`               | Infracost diff                                      | Who accepts the recurring cost                                |

---

## 3. Rate every finding against the rubric

| Severity | Test                                                                         |
| :------- | :--------------------------------------------------------------------------- |
| blocker  | Would you page someone at 03:00 for this, or owe an external party notice?   |
| major    | More expensive to fix in three months than today, and you can name who pays? |
| minor    | A tool output or counted metric backs it, and the fix is under ~15 minutes?  |
| nit      | A reasonable engineer could disagree and still be right?                     |

- Blocker ceilings in this family are limited to `process-merge-gating`, `process-rollback-path`
  and `process-deploy-sequencing`. A missing changelog entry is not a blocker.
- A blocker names the harmed party and the failure path; uncertainty lowers, never raises.
- Cap at **3 non-blocker findings** for this family, and at most **3 across docs + process +
  org-fit combined** when all three run in one review.
- At most **one test-related finding per review** across all aspects. If you and
  `review-beta:correctness` both have one, defer to theirs.

---

## 4. Not this aspect's job

From the taxonomy's de-duplication ledger:

| Subject                                            | Owner                                                                                                       |
| :------------------------------------------------- | :---------------------------------------------------------------------------------------------------------- |
| Whether the change is correct                      | `review-beta:correctness`                                                                                   |
| Whether the _data_ survives a bad change           | `review-beta:correctness` (`correctness-data-loss`) — this aspect owns whether the _deploy_ can be reversed |
| Whether an investigator can prove who did it       | `review-beta:security` (`sec-audit-trail-completeness`) — this aspect owns whether an operator can see it   |
| Breaking a published code/RPC contract             | `review-beta:design` (`design-backward-compatibility`) — this aspect owns only our own versions coexisting  |
| Whether the repo's own written rules were violated | `review-beta:org-fit` (`org-fit-repo-stated-rules`)                                                         |
| Reviewer self-grading, LOC/hour, branch currency   | Deleted from the taxonomy. Do not resurrect them                                                            |

`process-test-presence` and `correctness-changed-code-coverage` were merged into
`correctness-test-coverage`; do not raise a separate "no test" finding here.

---

## 5. Return contract

Return this and nothing else. No preamble, no narration.

```markdown
## review-beta:process

VERDICT: PASS | FAIL
SCOPE: <what was reviewed — diff range, branch, or repo config>
COUNTS: blocker=<n> major=<n> minor=<n> nit=<n> (tool=<n> judged=<n>)

| Sev     | Location                          | Dimension             | Problem                                                                                                        | Remedy                                                                           | Confidence |
| :------ | :-------------------------------- | :-------------------- | :------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------- | :--------- |
| blocker | db/migrate/0042_drop_legacy.sql:1 | process-rollback-path | Migration is irreversible and the path is in `.review/risk-paths.yaml`; no down migration and no runbook entry | Add the reverse migration, or gate the drop behind a flag with a documented undo | high       |

UNAVAILABLE:

- <dimension> — <signal that was missing, or the capability probe that disabled it>
```

- `VERDICT: FAIL` iff at least one **blocker** survives.
- Every row cites a taxonomy dimension id — that is how the parent de-duplicates aspects.
- `Location` is `file:line`; use line `0` for repo-level findings such as branch protection.
- `Confidence` is `high` | `medium` | `low`; a `low` row states what would confirm it.
- One row per finding, sorted blocker → major → minor → nit.
- With no findings, emit the header block with `VERDICT: PASS`, zeroed counts, and `NO FINDINGS`.
- Omit `UNAVAILABLE` when every dimension had its signal.
- Where a judged finding could have been a rule, append `AUTOMATION: <the rule to encode>`.

---

## 6. Related

| Skill                     | Relationship                                                              |
| :------------------------ | :------------------------------------------------------------------------ |
| `review-beta`             | The orchestrator that invokes this aspect and merges its report           |
| `review-beta:correctness` | Owns test coverage and quality; this aspect owns whether CI gates on them |
| `review-beta:org-fit`     | Owns the repo's own written rules and CI-pipeline reuse                   |
