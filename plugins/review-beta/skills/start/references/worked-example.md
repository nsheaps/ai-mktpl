# Worked example — a three-aspect review

## Contents

1. [The change](#1-the-change)
2. [What the aspects returned](#2-what-the-aspects-returned)
3. [Normalization and de-duplication](#3-normalization-and-de-duplication)
4. [Verification](#4-verification)
5. [The synthesized report](#5-the-synthesized-report)
6. [What this example is meant to show](#6-what-this-example-is-meant-to-show)

Reference for `review-beta` §5. One run, end to end, on a small realistic diff.

---

## 1. The change

A PR adding a bulk-export endpoint: `api/export.py` (new route), `db/queries.py` (new query),
`README.md` (usage snippet). No new dependency, no migration, no deployment manifest in the repo.

Gates: all six pass. Scaling (§2): an ordinary feature diff touching a request path and a doc →
`correctness`, `security`, `design`, plus `docs` for the README hunk. `process` and `org-fit`
are scaled out — the repo has no deployment surface and the diff changes no CI or manifest file.

---

## 2. What the aspects returned

`review-beta:correctness`:

| Sev     | Location         | Dimension                    | Problem                                                                      | Confidence |
| :------ | :--------------- | :--------------------------- | :--------------------------------------------------------------------------- | :--------- |
| major   | db/queries.py:60 | correctness-algorithmic-cost | Per-row `session.get()` inside the export loop; N+1 over request-sized input | high       |
| blocker | api/export.py:24 | correctness-null-absence     | `request.args['since']` parsed with no guard; `None` reaches `datetime`      | medium     |

`review-beta:security`:

| Sev     | Location         | Dimension                      | Problem                                               | Confidence |
| :------ | :--------------- | :----------------------------- | :---------------------------------------------------- | :--------- |
| blocker | db/queries.py:60 | sec-injection-interpreter      | `ORDER BY {sort}` interpolated from a query parameter | high       |
| major   | api/export.py:24 | sec-resource-exhaustion-limits | Unauthenticated route with no page-size cap           | medium     |

`review-beta:design`: `NO FINDINGS`, with `UNAVAILABLE: design-duplication — jscpd not installed`.

`review-beta:docs`:

| Sev   | Location     | Dimension                       | Problem                                               | Confidence |
| :---- | :----------- | :------------------------------ | :---------------------------------------------------- | :--------- |
| major | README.md:31 | docs-getting-started-executable | Snippet calls `/v1/export`; the route is `/v2/export` | high       |

---

## 3. Normalization and de-duplication

Severities map: blocker → P0, major → P1.

Two rows share `db/queries.py:60` but carry different dimension ids
(`correctness-algorithmic-cost`, `sec-injection-interpreter`). **Not a duplicate** — one is a cost
defect, one is an injection. Both survive, as separate rows.

Two rows share `api/export.py:24`, again with different ids. Also not a duplicate. Had both aspects
reported `sec-resource-exhaustion-limits` at that line, they would merge into one row with
`Aspect(s): security, correctness` and the higher of the two severities.

---

## 4. Verification

| Row                                                    | Rule applied                           | Outcome                                                                                              |
| :----------------------------------------------------- | :------------------------------------- | :--------------------------------------------------------------------------------------------------- |
| P0 `sec-injection-interpreter`                         | Refutation attempt                     | Read `db/queries.py:52-64`: `sort` is interpolated with no allowlist. Cannot refute → stands at P0   |
| P0 `correctness-null-absence`, confidence medium       | Refutation attempt                     | Read `api/export.py:18-26`: the route decorator supplies `since` a default. Refuted → dropped, noted |
| P1 `correctness-algorithmic-cost`                      | P1 with a tool signal (Semgrep rule)   | Accepted without re-check                                                                            |
| P1 `sec-resource-exhaustion-limits`, confidence medium | P1 judged, no tool signal              | Independent re-check: no `limit` parameter anywhere on the route. Confirmed, kept at P1              |
| P1 `docs-getting-started-executable`                   | P1 with a tool signal (lychee/doctest) | Accepted without re-check                                                                            |

One P0 dropped. That is the step earning its cost: reported, it would have sent the author to a
line that was already correct.

---

## 5. The synthesized report

```markdown
## Review — PR #418 bulk export endpoint

VERDICT: FAIL
GATES: 6 passed, 0 failed
ASPECTS: 4 run, 1 passed, 3 failed
COUNTS: P0=1 P1=3 P2=0 P3=0 (after de-duplication and verification)

| Sev | Location         | Dimension                       | Aspect(s)   | Problem                                               | Remedy                                              | Conf   |
| :-- | :--------------- | :------------------------------ | :---------- | :---------------------------------------------------- | :-------------------------------------------------- | :----- |
| P0  | db/queries.py:60 | sec-injection-interpreter       | security    | `ORDER BY {sort}` interpolated from a query parameter | Map `sort` through an allowlist of column names     | high   |
| P1  | api/export.py:24 | sec-resource-exhaustion-limits  | security    | Unauthenticated route with no page-size cap           | Add a max page size and a per-caller rate limit     | medium |
| P1  | db/queries.py:60 | correctness-algorithmic-cost    | correctness | Per-row `session.get()` inside the export loop        | Replace with one batched query keyed by id          | high   |
| P1  | README.md:31     | docs-getting-started-executable | docs        | Snippet calls `/v1/export`; the route is `/v2/export` | Update the snippet and add it to the doc smoke test | high   |

NOT REVIEWED:

- review-beta:process, review-beta:org-fit — scaled out: no deployment surface, no CI or manifest file in the diff
- design-duplication — jscpd not installed; no clone detection ran

NOTES:

- Dropped: correctness-null-absence at api/export.py:24 — refuted, the route decorator supplies a default for `since`
```

---

## 6. What this example is meant to show

| Step                | The point                                                                                   |
| :------------------ | :------------------------------------------------------------------------------------------ |
| Scaling             | Two aspects were never spawned, and the report says so                                      |
| Same location twice | Different dimension ids are different findings; merging them would have hidden the N+1      |
| Verification        | The one P0 that was wrong is the one verification caught. Both P0s looked equally plausible |
| Unavailable         | A missing detector is reported as a gap, never filled in by eyeballing the diff             |
| Relay               | Problem and remedy text is the aspect's wording, unedited, so each row stays traceable      |
