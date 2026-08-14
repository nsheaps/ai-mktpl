---
name: best-practices
description: Invoked by review-beta:start, which routes every review request and decides which aspects apply — use that entry skill first; this is one of the aspects it delegates to. Reviews whether code follows the idiomatic practice its own ecosystem publishes, running scripts/probe-best-practices.sh — golangci-lint, clippy, ruff, biome, rubocop, stylelint, swiftlint, ktlint, tflint, phpcs — and reporting only what those linters decide, so "unidiomatic" is settled by each community's rule catalogue rather than by taste. Returns a structured findings report with a verdict. NOT for whether the code is correct (review-beta:correctness), whether it is well factored (review-beta:design), or whether it matches this org's own declared conventions (review-beta:org-fit).
context: fork
background: false
allowed-tools: Read, Grep, Glob, Bash(${CLAUDE_SKILL_DIR}/scripts/probe-best-practices.sh:*)
---

# review-beta:best-practices

Review the code touched by $ARGUMENTS against its ecosystem's published idiom, and return the
findings report defined in §5. With no `$ARGUMENTS`, review the working-tree diff against the
default branch.

This is one aspect subskill of a multi-aspect review. The parent orchestrator
(`review-beta:start`) collects this report alongside the other aspects and synthesizes them, so
the report is the whole product: **the parent sees only the return value, never any of this
reasoning.**

This aspect is different from the other six in one way that governs everything below. The
[canonical review taxonomy](references/dimensions.md) has no "best practices" family — its 108
dimensions are all owned elsewhere. So this aspect has **no dimensions of its own beyond what a
linter defines**. Its dimension ids name a language's linter, and its findings are that linter's
findings. There is nothing here to judge by hand.

---

## 1. Run the probe first — and effectively only

```
${CLAUDE_SKILL_DIR}/scripts/probe-best-practices.sh [--base <ref>] [<repo-root>]
```

It runs each ecosystem's opinionated linter where that binary resolves, emitting
`SEVERITY|FILE|LINE|DIMENSION|MESSAGE` plus `#`-prefixed metadata. `--list` prints the tool table
without running anything. Fields are `|`-separated; a literal pipe inside FILE or MESSAGE arrives
escaped as `\|`, so the field count is always five.

**Output-format coverage.** The probe parses each tool's own stdout, so a filter that does not
match its tool is a silent zero-findings bug rather than a crash. **No tool in this family has been
run against captured output** — every row's filter is assumed, and none is pinned by a fixture in
[`tests/run-probe-tests.sh`](../../tests/run-probe-tests.sh), which asserts only that this probe's
`--list` runs. Treat an unexpected zero from any row as suspect, and confirm by running the linter
directly before reporting the language clean.

| Rule                  | Consequence                                                                              |
| :-------------------- | :--------------------------------------------------------------------------------------- |
| Probe, then battery   | If `.review/battery.sarif` exists, adjudicate its partitioned results, do not re-run     |
| No tool, no finding   | A language whose linter is absent is **unavailable** and produces zero findings — say so |
| Relay, don't re-judge | The linter already decided. Render its diagnostic; do not restate it as your own opinion |

**Why the discipline is stricter here.** "This isn't idiomatic" is the single easiest finding to
invent — every codebase looks unidiomatic to someone, and an unbacked idiom finding is
indistinguishable from a preference. A reviewer that fills a missing linter's gap by eyeballing
the diff will always find what it went looking for. Report the language unavailable instead.

**Which linters this aspect deliberately does not run**, because another aspect owns them and a
second run would duplicate findings the parent then has to merge away:

| Tool                       | Owner                     |
| :------------------------- | :------------------------ |
| eslint, shellcheck         | `review-beta:org-fit`     |
| go vet, tsc, mypy, semgrep | `review-beta:correctness` |
| jscpd, knip                | `review-beta:design`      |

---

## 2. Adjudicate only two things

Everything else is relay. The two calls that are genuinely yours:

| Call                   | Question                                                                                                                                                 |
| :--------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------- |
| In-diff?               | Did this change introduce the diagnostic, or was it already there? A pre-existing hit on an untouched line is noise in a change review — drop it         |
| Suppressed on purpose? | Is there an adjacent `//nolint`, `# noqa`, `#[allow(...)]`, `rubocop:disable` with a stated reason? A deliberate, explained suppression is not a finding |

Neither call needs a tool. Both need you to read the cited line before reporting it.

Do **not** re-rank a linter's own severity. Each row in the probe's tool table carries the
severity ceiling for that language, and the rating rubric in §3 applies within it.

---

## 3. Rate every finding, and stay inside the licence

| Severity | Test                                                                         |
| :------- | :--------------------------------------------------------------------------- |
| blocker  | Would you page someone at 03:00 for this, or owe an external party notice?   |
| major    | More expensive to fix in three months than today, and you can name who pays? |
| minor    | A tool output or counted metric backs it, and the fix is under ~15 minutes?  |
| nit      | A reasonable engineer could disagree and still be right?                     |

- **No dimension in this family carries a blocker ceiling.** Unidiomatic code is not an outage.
  A finding that feels like a blocker belongs to `correctness` or `security` — route it, do not
  inflate it here.
- Cap at **5 findings** for this family, ranked by severity then by how many times the same rule
  fires. A linter can emit hundreds of hits; relaying them all makes the parent's report unusable
  and is what a CI job is for.
- When one rule fires more than three times, report it **once** with a count and the first
  location, and append an `AUTOMATION:` line naming the rule to turn on in CI. A repeated
  mechanical hit is a missing gate, not fifteen review comments.

---

## 4. Not this aspect's job

| Subject                                                      | Owner                                 |
| :----------------------------------------------------------- | :------------------------------------ |
| Whether the code does the right thing                        | `review-beta:correctness`             |
| Whether the abstraction, contract or coupling is right       | `review-beta:design`                  |
| Whether it matches this org's declared rules and house style | `review-beta:org-fit`                 |
| Whether a vulnerable pattern is idiomatic-but-unsafe         | `review-beta:security`                |
| Whether a skill, plugin or hook is well built                | `review-beta:agentic-configuration`   |
| Formatting the repo's own `format`/`lint` task already fixes | the hard gates in `review-beta:start` |

---

## 5. Return contract

Return this and nothing else. No preamble, no narration.

```markdown
## review-beta:best-practices

VERDICT: PASS | FAIL
SCOPE: <what was reviewed — diff range or paths>
COUNTS: blocker=<n> major=<n> minor=<n> nit=<n> (tool=<n> judged=<n>)

| Sev   | Location    | Dimension   | Problem                                                               | Remedy                                                   | Confidence |
| :---- | :---------- | :---------- | :-------------------------------------------------------------------- | :------------------------------------------------------- | :--------- |
| major | pkg/x.go:41 | bp-go-idiom | golangci-lint `errcheck`: return value of `w.Write` is unchecked (×4) | Check and wrap the error, or assign to `_` with a reason | high       |

UNAVAILABLE:

- <language> — <linter that was missing>
```

- `VERDICT: FAIL` iff at least one **blocker** survives. No dimension here can produce one, so
  this aspect returns PASS in every ordinary run — that is correct, not a bug.
- Every row cites a `bp-*` dimension id and names the linter rule inside the Problem text. That
  pairing is how the parent de-duplicates this aspect against the others, and how a disputed
  finding is settled by reading the rule's own documentation.
- `Location` is `file:line`; line `0` only when the tool reported no line.
- `Confidence` is `high` | `medium` | `low`. A relayed linter hit is `high`; anything lower means
  you are guessing and should not be reporting it at all.
- One row per finding, sorted blocker → major → minor → nit. Collapse repeats of one rule into a
  single row with a `(×n)` count.
- With no findings, emit the header block with `VERDICT: PASS`, zeroed counts, and `NO FINDINGS`.
- `UNAVAILABLE` is never omitted when a language present in the diff had no linter — a silent
  zero reads as coverage.
- Where a repeated hit should be a CI gate, append `AUTOMATION: <the rule to turn on>`.

---

## 6. Related

| Skill                     | Relationship                                                          |
| :------------------------ | :-------------------------------------------------------------------- |
| `review-beta:start`       | The orchestrator that invokes this aspect and merges its report       |
| `review-beta:org-fit`     | Owns the org's own declared conventions, and runs eslint + shellcheck |
| `review-beta:correctness` | Owns whether the code works, and runs the type checkers               |
