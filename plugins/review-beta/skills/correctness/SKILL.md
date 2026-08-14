---
name: correctness
description: Invoked by review-beta:start, which routes every review request and decides which aspects apply — use that entry skill first; this is one of the aspects it delegates to. Reviews a change for correctness defects and returns a structured findings report with a verdict, running scripts/probe-correctness.sh for every mechanically decidable dimension before spending any judgement. Covers the taxonomy's 19 correctness dimensions over a diff — boundary conditions, null and absent values, numeric precision, error propagation, resource lifecycle, concurrency, idempotency, transactional atomicity, data loss, algorithmic cost, termination bounds, and the tests that would have caught each. NOT for attacker-reachable vulnerabilities (review-beta:security), abstraction and coupling quality (review-beta:design), or whether tests are gated in CI (review-beta:process).
context: fork
background: false
compatibility: "Requires Claude Code v2.1.218 or later. Earlier versions ignore `background: false`, so this skill forks into the background and returns nothing to the caller — which reads as a clean review rather than an error."
allowed-tools: Read, Grep, Glob, Bash(${CLAUDE_SKILL_DIR}/scripts/probe-correctness.sh:*)
---

# review-beta:correctness

Review the change at $ARGUMENTS for correctness defects and return the findings report defined in
§5. With no `$ARGUMENTS`, review the working-tree diff against the default branch.

This is one aspect subskill of a multi-aspect review. The parent orchestrator (`review-beta:start`)
collects this report alongside the other five aspects and synthesizes them, so the report is the
whole product: **the parent sees only the return value, never any of this reasoning.**

`background: false` is deliberate — the parent needs the findings inside its own turn, and a
backgrounded fork gets a narrower tool set than the Bash-plus-Read work below requires.

---

## 1. Run the probe first — always

```
${CLAUDE_SKILL_DIR}/scripts/probe-correctness.sh [--base <ref>] [<repo-root>]
```

It emits `SEVERITY|FILE|LINE|DIMENSION|MESSAGE` findings plus `#`-prefixed metadata: which tool
ran, which was missing, which dimensions are deferred to CI, and whether a merged
`.review/battery.sarif` already exists. Run `--list` to see the tool table without running it.

Fields are `|`-separated; a literal pipe inside FILE or MESSAGE arrives escaped as `\|`, so the field count is always five.

Three rules govern what you do with that output.

| Rule                | Consequence                                                                                                                                     |
| :------------------ | :---------------------------------------------------------------------------------------------------------------------------------------------- |
| Probe, then battery | If `.review/battery.sarif` exists, its partitioned results are authoritative — adjudicate those and do not re-run a scanner by hand             |
| No tool, no finding | A dimension whose tool reported `status=missing` or `deferred=` is **unavailable** and produces zero findings. Say so in §5's UNAVAILABLE block |
| Never re-derive     | Do not hand-check what the probe decided. A reviewer told to look for overflow in a diff will find overflow whether or not it is there          |

**Output-format coverage.** The probe parses each tool's own stdout, so a filter that does not match its tool is a silent zero-findings bug rather than a crash. The shapes emitted by `semgrep` (`--vim`) and `mypy` were verified against real output from those tools; the ones with a captured fixture are pinned and asserted in [`tests/run-probe-tests.sh`](../../tests/run-probe-tests.sh). The shapes assumed for `tsc`, `go vet`, `errcheck`, `eslint`, `diff-cover` are **unverified** — those tools could not be run here. Treat an unexpected zero from one of them as suspect, and confirm by running it directly before reporting the dimension clean.

The second rule is the one that costs discipline. It exists because the failure mode of this
family is not a missed defect — it is a confident, plausible, wrong one, which burns author trust
faster than an escape does.

---

## 2. Adjudicate only the residue

The dimension table, with each dimension's question, severity ceiling, automation tier and the
exact residual left to judgement, is in [references/dimensions.md](references/dimensions.md). Read
it once, then work only the residue. The residues that recur:

| Dimension                       | The tool decided                        | You decide                                                       |
| :------------------------------ | :-------------------------------------- | :--------------------------------------------------------------- |
| `correctness-null-absence`      | Every typed dereference                 | Untyped boundaries — JSON parse, FFI, `any` at an API edge       |
| `correctness-error-propagation` | Unchecked and discarded failure signals | Whether a caught-and-logged error should have aborted            |
| `correctness-concurrency`       | Races the existing tests scheduled      | Interleavings no existing test schedules                         |
| `correctness-domain-invariants` | Illegal assignments outside transitions | Naming the invariant and the transition that violates it         |
| `correctness-partial-failure`   | Fan-out around side effects             | Whether the resulting partial state is acceptable to the domain  |
| `correctness-data-loss`         | Destructive DDL and IaC operations      | Whether the stated recovery path has ever been exercised         |
| `correctness-algorithmic-cost`  | IO in a loop, missing indexes           | Whether the input is actually request-sized in production        |
| `correctness-test-quality`      | Surviving mutants, flake reruns         | Whether a surviving mutant is a real gap or an equivalent mutant |

`correctness-test-coverage` is `agent: skip` in the taxonomy — its tool returns a decision, not
candidates. Relay the probe's finding verbatim; do not re-judge it.

---

## 3. Rate every finding against the rubric

| Severity | Test                                                                         |
| :------- | :--------------------------------------------------------------------------- |
| blocker  | Would you page someone at 03:00 for this, or owe an external party notice?   |
| major    | More expensive to fix in three months than today, and you can name who pays? |
| minor    | A tool output or counted metric backs it, and the fix is under ~15 minutes?  |
| nit      | A reasonable engineer could disagree and still be right?                     |

Four constraints, from the taxonomy's rubric:

- A finding may never exceed its dimension's ceiling. If it does, it belongs to another dimension.
- A blocker must name the harmed party and a reproducible failure path — inputs → wrong output.
  Without one it is a major at most.
- Uncertainty lowers severity, never raises it. Drop a level and state what would confirm it.
- Cap the report at **3 non-blocker findings**, blockers exempt, ranked by severity then signal
  strength. Drop the rest silently.

---

## 4. Not this aspect's job

From the taxonomy's de-duplication ledger. Route rather than report:

| Subject                                             | Owner                                                       |
| :-------------------------------------------------- | :---------------------------------------------------------- |
| Attacker-controlled amplification across a boundary | `review-beta:security` (`sec-resource-exhaustion-limits`)   |
| Personal data reaching a sink                       | `review-beta:security` (`sec-personal-data-handling`)       |
| Whether the deploy can be reversed                  | `review-beta:process` (`process-rollback-path`)             |
| Whether an operator can see the failure             | `review-beta:process` (`process-telemetry-instrumentation`) |
| Whether the test is gated in CI at all              | `review-beta:process` (`process-merge-gating`)              |
| Abstraction, coupling and duplication quality       | `review-beta:design`                                        |
| Dead or unreferenced code, import cycles            | Hard gates — the run aborts on these, they are not findings |

Self-inflicted unbounded growth stays here (`correctness-termination-bounds`); the same loop
reachable by an attacker is `sec-resource-exhaustion-limits`. Multi-step mutations that are not
atomic stay here; an atomic mutation reaching an illegal end state is `correctness-domain-invariants`.

---

## 5. Return contract

Return this and nothing else. No preamble, no narration, no restating the taxonomy.

```markdown
## review-beta:correctness

VERDICT: PASS | FAIL
SCOPE: <what was reviewed — diff range or paths>
COUNTS: blocker=<n> major=<n> minor=<n> nit=<n> (tool=<n> judged=<n>)

| Sev     | Location         | Dimension                           | Problem                                                                    | Remedy                                                                    | Confidence |
| :------ | :--------------- | :---------------------------------- | :------------------------------------------------------------------------- | :------------------------------------------------------------------------ | :--------- |
| blocker | src/ledger.go:88 | correctness-transactional-integrity | SELECT-then-UPDATE with no row lock; two concurrent transfers double-spend | Add `FOR UPDATE` to the balance read, or a version predicate on the write | high       |

UNAVAILABLE:

- <dimension> — <tool that was missing or deferred>
```

Rules that make the report usable:

- `VERDICT: FAIL` iff at least one **blocker** survives. Nothing else changes the verdict.
- Every row cites a taxonomy dimension id — that is how the parent de-duplicates aspects.
- `Location` is `file:line`. Use line `0` only when a finding genuinely has no line.
- `Confidence` is `high` | `medium` | `low`, and `low` findings must state what would confirm them.
- `Remedy` is the concrete edit to make, not a restatement of the problem.
- One row per finding, sorted blocker → major → minor → nit. Do not collapse repeats across files.
- With no findings, emit the header block with `VERDICT: PASS`, zeroed counts, and the literal
  line `NO FINDINGS` in place of the table.
- Omit `UNAVAILABLE` when every dimension had its tool.
- Where a judged finding could have been a rule, append one line: `AUTOMATION: <the rule to encode>`.

---

## 6. Related

| Skill                  | Relationship                                                               |
| :--------------------- | :------------------------------------------------------------------------- |
| `review-beta:start`    | The orchestrator that invokes this aspect and merges its report            |
| `review-beta:security` | Owns attacker-reachable versions of the same mechanisms                    |
| `review-beta:process`  | Owns whether the missing test is gated, and whether the change is undoable |
