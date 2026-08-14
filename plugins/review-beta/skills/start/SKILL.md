---
name: start
description: Start here for every review request, before reaching for any other review skill. Works out what kind of review was actually asked for — documentation, code, agent configuration, CI, front-end, mobile, or a whole-repo audit — and returns a table of contents naming which aspect skills apply and in what order. Then runs them, each in its own forked context, verifies the findings before trusting them, and synthesizes one de-duplicated report with a single verdict. Trigger phrases — "review this", "code review", "review the docs", "review my skill", "audit this repo", "run a full review", "is this ready to merge", "review this PR". Use this first even when one aspect looks obvious — choosing an aspect directly skips the hard gates, the scaling decision, and the record of what went unreviewed. Holds no review criteria of its own and produces no findings — the aspect skills do that.
---

# review-beta

Review the target at $ARGUMENTS. This skill decides **which** review to run and merges what comes
back. It holds no review criteria: an aspect's criteria live in that aspect's own skill, and
inventing criteria here is how the two copies drift apart.

Work in this order. §1 is the disambiguation step and is never skipped — a review whose scope was
never stated cannot be read as anything but total coverage.

---

## 1. Route the request — state this before doing anything else

"Review this" is ambiguous. Decide what was asked for, then say so. Emit the routing decision as a
table of contents before running a single aspect:

```
REVIEWING: <target>
KIND: <the row you matched below>
ASPECTS: <ordered list>
SKIPPED: <aspects not run, and why>
```

| What you were handed                                                       | Aspects, in order                                                 |
| :------------------------------------------------------------------------- | :---------------------------------------------------------------- |
| Prose docs — README, guide, changelog, ADR                                 | `docs`, then `org-fit` if house style is in question              |
| Agent configuration — skills, plugins, hooks, agents, commands, MCP config | `agentic-configuration`, then `docs` if it ships references       |
| CI, workflows, pipelines, release automation                               | `security`, `process`, `org-fit`                                  |
| Front-end / UI code                                                        | `correctness`, `best-practices`, `org-fit`, `design`              |
| Mobile code                                                                | `correctness`, `best-practices`, `security`, `process`            |
| Back-end / service / library code                                          | `correctness`, `security`, `design`, `best-practices`             |
| Infrastructure as code, manifests, container builds                        | `security`, `org-fit`, `process`                                  |
| A pull request, mixed content                                              | route each file group by the rows above, then union               |
| A whole repo, no diff ("audit this")                                       | every aspect, plus the `scope: repo` dimensions the PR path skips |

Then scale to the size of the change — routing says which aspects are _eligible_, size says how
many are _worth it_:

| Change                                         | Trim to                                                                       |
| :--------------------------------------------- | :---------------------------------------------------------------------------- |
| ≤ ~20 lines, one file, no new dependency       | the routed set ∩ {`correctness`, `security`, `docs`, `agentic-configuration`} |
| Ordinary feature or fix diff                   | the routed set, minus `process` and `org-fit`                                 |
| New public interface, migration, or dependency | the full routed set, nothing trimmed                                          |

Trim only within the routed set, never to nothing — if a rule would empty it, keep the first aspect
§1 routed, because a `PASS` over an empty finding set is the failure this plugin exists to prevent.
Trimmed aspects go in `NOT REVIEWED`: skipped deliberately is information, skipped silently is a hole.

---

## 2. Check the hard gates

Six checks are decided entirely by a tool that returns a decision, not candidates. They are not
dimensions and produce no findings:

| Gate                                    | Decided by                                                 |
| :-------------------------------------- | :--------------------------------------------------------- |
| Dead / unreferenced code                | Go `deadcode`, Knip, Vulture, TS `noUnusedLocals`          |
| Import cycles                           | dependency-cruiser `no-circular`, ArchUnit, import-linter  |
| CI expression / template injection      | `zizmor` `template-injection` / `github-env`; `actionlint` |
| Dependency pinning & lockfile integrity | frozen-install assertion, digest pinning, Scorecard        |
| Machine-detectable WCAG failures        | `axe-core` / `pa11y`, `eslint-plugin-jsx-a11y`             |
| Formatter / linter / editorconfig       | the repo's own `lint` or `format --check` task             |

**These gates are aspirational in this beta**: unlike every aspect in §3 they have no probe script
and no per-gate command, so apply one only where the repo's own CI already runs that tool, and
take the tool's verdict as the gate's. Three rules keep a gate from becoming the silent zero this
plugin argues against everywhere else:

- A gate whose tool is absent is `unavailable`, never `passed`, and never counts toward a pass.
- A failing gate does **not** abort the run — lead the report with it and review anyway. Losing
  the whole review to an unformatted tree tells the reader strictly less than the findings plus a
  red gate header, which is all CI had already told them.
- Never eyeball a gate. No tool, no verdict.

---

## 3. Discover and delegate

Aspect skills are the sibling skill directories of this one. Enumerate them rather than
hard-coding a list, so a newly added aspect participates without editing this file — but the glob
alone is not the admission test. A sibling directory is only an aspect if it also proves it
implements the aspect contract:

```
for d in "${CLAUDE_SKILL_DIR}"/../*/; do
  [ "$(basename "$d")" = "start" ] && continue
  f="$d/SKILL.md"
  [ -f "$f" ] || continue                                  # no skill, not an aspect
  grep -q '^context: fork' "$f" || continue                # must run isolated
  grep -qE '^## [0-9]+\. Return contract' "$f" || continue # must return the shared shape
  echo "$(basename "$d")"
done
```

Those three conditions are exactly what this orchestrator depends on: a `SKILL.md` to invoke,
`context: fork` so the aspect's reading never lands here, and a return contract so its report
parses uniformly. A directory matching the glob but failing any of them is NOT invoked — record it
in `NOT REVIEWED` as an unrecognized aspect directory, so a half-built or mis-named skill is
visible rather than silently executed.

| Aspect                              | Family it owns                                                                         |
| :---------------------------------- | :------------------------------------------------------------------------------------- |
| `review-beta:correctness`           | Logic, edges, concurrency, data loss, tests (19 dimensions)                            |
| `review-beta:security`              | AppSec, personal data, supply chain (24)                                               |
| `review-beta:design`                | Abstraction, contracts, coupling (13)                                                  |
| `review-beta:docs`                  | Documentation truth and usability (18)                                                 |
| `review-beta:process`               | How the change arrives and rolls out (18)                                              |
| `review-beta:org-fit`               | Fit with declared org assets and rules (16)                                            |
| `review-beta:best-practices`        | Ecosystem-idiomatic practice, per each language's own linter                           |
| `review-beta:agentic-configuration` | Whether agent configuration — skills, plugins, hooks, agents, commands — is well built |

Invoke each with `Skill(skill: "review-beta:<aspect>", args: "<target>")`, passing the same target
to every aspect. An aspect carrying `context: fork` runs in a forked context and returns only its
report — its reading, greping and battery output never enter this context, which is the point.

Run aspects independently. An aspect that fails or returns nothing is recorded in `NOT REVIEWED`
rather than retried inline or substituted for. Guessing its findings would defeat the isolation.

---

## 4. Normalize, de-duplicate, verify

**Normalize severities.** The taxonomy aspects report `blocker|major|minor|nit`;
`review-beta:agentic-configuration` reports `P0|P1|P2`. Map before merging, and treat a missing
`Confidence` column as `high`:

| Aspect word | Report band | Meaning                      |
| :---------- | :---------- | :--------------------------- |
| blocker     | P0          | Must not merge               |
| major       | P1          | Should not merge as-is       |
| minor       | P2          | May merge                    |
| nit         | P3          | Never blocks, never required |

**De-duplicate.** Two rows are the same finding when their location **and** dimension/check id
match. Merge them into one row and list both reporting aspects. Where aspects disagree on severity,
keep the highest. Same location, different ids, is **not** a duplicate — two aspects legitimately
fault the same line for different reasons, and collapsing them hides one reason.

**Verify before reporting.** A plausible-but-wrong finding costs more than a missed one: it burns
the author's time, and the next real finding gets less benefit of the doubt.

| Finding                                   | Verification                                                                                                                                                                  |
| :---------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Any P0, or any row with `Confidence: low` | **Refutation attempt** — re-read the cited `file:line` yourself and try to prove the finding wrong. Look for the guard, the caller, the sanitizer, the test the aspect missed |
| Two aspects agree on the same location    | Accept **only if their probe rows ran different binaries, or none**. Two forks reading one tool's stdout is one observation, not two, and still owes a refutation attempt     |
| P1 with a named tool output as its signal | Accept. The tool already decided; re-checking duplicates it                                                                                                                   |
| P1 judged with no tool signal             | **Independent re-check** — ask a second aspect that could see the same defect, or re-read the location before reporting                                                       |
| P2 / P3                                   | No verification. It costs more than the finding is worth                                                                                                                      |

A finding you cannot refute stands, at its stated severity. A finding refuted is dropped, and the
refutation is worth one line in `NOTES` — it is how the aspect gets calibrated. A finding you can
neither confirm nor refute drops one severity band and states what would settle it.

---

## 5. Synthesize

Return one report:

```markdown
## Review — <target>

VERDICT: PASS | FAIL
KIND: <the §1 row that was matched>
GATES: <n> passed, <n> failed, <n> unavailable <— names of any that failed or were unavailable>
ASPECTS: <n> run, <n> passed, <n> failed<, n unavailable>
COUNTS: P0=<n> P1=<n> P2=<n> P3=<n> (after de-duplication and verification)

| Sev | Location | Dimension | Aspect(s) | Problem | Remedy | Conf |
| :-- | :------- | :-------- | :-------- | :------ | :----- | :--- |

NOT REVIEWED:

- <aspect that was not run, and why — routed out, scaled out, failed, or returned nothing>
- <dimension an aspect reported UNAVAILABLE, and the tool it needed>

NOTES:

- <finding dropped in verification, and what refuted it>
- <AUTOMATION line relayed from an aspect>
```

- `VERDICT: FAIL` iff at least one P0 survives de-duplication and verification.
- Sort P0 → P1 → P2 → P3, then by location.
- Do not re-word an aspect's problem or remedy text — relay it, so the finding stays traceable to
  the aspect that raised it.
- `NOT REVIEWED` is never omitted. Every review has a boundary; an unstated one reads as coverage.
- Omit `NOTES` when nothing was dropped and no aspect emitted an `AUTOMATION` line.

[`tests/run-probe-tests.sh`](../../tests/run-probe-tests.sh) pins the `docs`, `security`, `design`
and `org-fit` output filters against captured tool output ([provenance](../../tests/fixtures/SOURCES.md));
`correctness`, `process` and `best-practices` get only a syntax and `--list` check, so treat an
unexpected zero from those three as suspect. Run the suite after changing any probe: a filter that
no longer matches reports zero silently, which is worse than an absent tool.

A worked example — a three-aspect run with one duplicate, one refuted P0 and one unavailable
dimension — is in [references/worked-example.md](references/worked-example.md). Read it before the
first run in a session; it is the fastest way to see the merge and verification steps applied.
