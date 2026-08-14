---
name: security
description: Invoked by review-beta:start, which routes every review request and decides which aspects apply — use that entry skill first; this is one of the aspects it delegates to. Reviews a change for security defects and returns a structured findings report with a verdict, running scripts/probe-security.sh — the same scanners the org lint-* actions run — before spending any judgement. Covers the taxonomy's 24 security dimensions — interpreter and render-sink injection, path traversal, SSRF, deserialization, authorization and field-level exposure, authentication, cryptography, secret material, personal-data handling and retention, audit trail, model trust boundaries, CI privilege, and the software supply chain. NOT for self-inflicted correctness bugs with no attacker path (review-beta:correctness), and NOT for whether CI gates are required (review-beta:process).
context: fork
background: false
compatibility: "Requires Claude Code v2.1.218 or later. Earlier versions ignore `background: false`, so this skill forks into the background and returns nothing to the caller — which reads as a clean review rather than an error."
allowed-tools: Read, Grep, Glob, Bash(${CLAUDE_SKILL_DIR}/scripts/probe-security.sh:*)
---

# review-beta:security

Review the change at $ARGUMENTS for security defects and return the findings report defined in §5.
With no `$ARGUMENTS`, review the working-tree diff against the default branch.

This is one aspect subskill of a multi-aspect review. The parent orchestrator (`review-beta:start`)
collects this report alongside the other five aspects and synthesizes them, so the report is the
whole product: **the parent sees only the return value, never any of this reasoning.**

`background: false` is deliberate — the parent needs the findings inside its own turn, and a
backgrounded fork gets a narrower tool set than the Bash-plus-Read work below requires.

---

## 1. Run the probe first — always

```
${CLAUDE_SKILL_DIR}/scripts/probe-security.sh [--base <ref>] [<repo-root>]
```

It runs the scanners this family is decided by — trufflehog, gitleaks, secretlint, Semgrep,
osv-scanner, grype, trivy, checkov, kics, zizmor, actionlint, syft — and emits
`SEVERITY|FILE|LINE|DIMENSION|MESSAGE` plus `#`-prefixed metadata for every tool that ran, was
missing, or is deferred. `--list` prints the tool table without running anything.

Fields are `|`-separated; a literal pipe inside FILE or MESSAGE arrives escaped as `\|`, so the field count is always five.

In CI these same scanners arrive from the org's composite actions
(`nsheaps/github-actions/.github/actions/lint-{trufflehog,gitleaks,secretlint,checkov,kics,grype,trivy,syft}`).
Do not reimplement them; the probe calls the local binaries the actions install.

| Rule                 | Consequence                                                                                                              |
| :------------------- | :----------------------------------------------------------------------------------------------------------------------- |
| Probe, then battery  | If `.review/battery.sarif` exists, its partitioned results are authoritative — adjudicate those, re-run nothing          |
| No tool, no finding  | A dimension whose scanner is missing or deferred is **unavailable** and produces zero findings. List it in §5            |
| Verified beats found | `trufflehog --results=verified` findings are reported **without adjudication** — a live-verified credential is a blocker |

**Output-format coverage.** The probe parses each tool's own stdout, so a filter that does not match its tool is a silent zero-findings bug rather than a crash. The shapes emitted by `semgrep` (`--vim`), `zizmor`, `actionlint` and `osv-scanner` were verified against real output from those tools; the ones with a captured fixture are pinned and asserted in [`tests/run-probe-tests.sh`](../../tests/run-probe-tests.sh). The shapes assumed for `trufflehog`, `gitleaks`, `secretlint`, `grype`, `trivy`, `checkov`, `kics`, `syft` are **unverified** — those tools could not be run here. Treat an unexpected zero from one of them as suspect, and confirm by running it directly before reporting the dimension clean.

Two rules earn their keep here specifically. A security reviewer with no scanner will confabulate
an attacker path for any input-shaped variable it sees; and an unverified secret candidate that
gets escalated to a blocker teaches the team to route around the review.

---

## 2. Adjudicate only the residue

The dimension table — question, ceiling, tier, and the exact residual — is in
[references/dimensions.md](references/dimensions.md). The residues that recur:

| Dimension                           | The tool decided                                | You decide                                                        |
| :---------------------------------- | :---------------------------------------------- | :---------------------------------------------------------------- |
| `sec-injection-interpreter`         | Source→sink taint with sanitizers modelled      | Whether the flagged source is genuinely attacker-reachable        |
| `sec-xss-render-sink`               | Data reaching an execution sink                 | The encoding context of that sink                                 |
| `sec-path-traversal`                | Taint to filesystem sinks                       | Symlink and case-folding edge cases on the target platform        |
| `sec-authz-enforcement`             | Route↔policy map, negative-authz test presence  | Whether the object-ownership check matches the domain's rules     |
| `sec-personal-data-handling`        | PII-named identifiers reaching sinks            | Whether the field is genuinely subject data, and the lawful basis |
| `sec-credential-scope-and-rotation` | Wildcard IAM actions, missing rotation metadata | Whether the widened scope is proportionate                        |
| `sec-model-input-trust-boundary`    | Untrusted source → prompt sink                  | Whether model output actually drives a privileged action          |
| `sec-dep-vuln-maintenance`          | Advisory matches in the resolved graph          | Whether the vulnerable path is reachable from this code           |

`sec-license-sbom` and `sec-ci-action-integrity` are `agent: skip`: relay the tool's decision
verbatim. `sec-secret-material-exposure` is reported without adjudication when verified.

---

## 3. Rate every finding against the rubric

| Severity | Test                                                                         |
| :------- | :--------------------------------------------------------------------------- |
| blocker  | Would you page someone at 03:00 for this, or owe an external party notice?   |
| major    | More expensive to fix in three months than today, and you can name who pays? |
| minor    | A tool output or counted metric backs it, and the fix is under ~15 minutes?  |
| nit      | A reasonable engineer could disagree and still be right?                     |

- Blocker ceilings in this family are restricted to the **reachable-attacker-path** and
  **personal-data** sets. A hardening suggestion with no reachable path is a major at most.
- A blocker must name the harmed party and the path: source, sink, and what the attacker controls.
- Uncertainty lowers, never raises. If you cannot show the source is attacker-reachable, drop a
  level and state what would confirm it.
- Cap at **3 non-blocker findings**, blockers exempt.

---

## 4. Not this aspect's job

From the taxonomy's de-duplication ledger:

| Subject                                               | Owner                                                                                                                        |
| :---------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------- |
| Self-inflicted unbounded growth with no attacker path | `review-beta:correctness` (`correctness-termination-bounds`)                                                                 |
| Whether the data survives a bad change                | `review-beta:correctness` (`correctness-data-loss`)                                                                          |
| Whether an operator can _see_ an event                | `review-beta:process` (`process-telemetry-instrumentation`) — this aspect owns whether an investigator can _prove_ it        |
| Whether a required check actually blocks merge        | `review-beta:process` (`process-merge-gating`)                                                                               |
| CI expression/template injection, dependency pinning  | Hard gates — the run aborts, they are not findings                                                                           |
| Third-party dependency worth its carrying cost        | `review-beta:design` (`design-third-party-dependency`) — this aspect owns whether it is vulnerable, unmaintained or impostor |

Within this family, two seams are pinned: presence of a secret _value_ is
`sec-secret-material-exposure`, while over-scope and rotation is `sec-credential-scope-and-rotation`;
may this principal touch this _object_ is `sec-authz-enforcement`, while may they read or write
this _field_ is `sec-field-level-exposure`.

---

## 5. Return contract

Return this and nothing else. No preamble, no narration.

```markdown
## review-beta:security

VERDICT: PASS | FAIL
SCOPE: <what was reviewed — diff range or paths>
COUNTS: blocker=<n> major=<n> minor=<n> nit=<n> (tool=<n> judged=<n>)

| Sev     | Location         | Dimension                 | Problem                                                                                     | Remedy                                                                     | Confidence |
| :------ | :--------------- | :------------------------ | :------------------------------------------------------------------------------------------ | :------------------------------------------------------------------------- | :--------- |
| blocker | api/report.py:41 | sec-injection-interpreter | Query built by f-string from `request.args['sort']`; taint reaches the SQL sink unsanitized | Bind `sort` as a parameter, or map it through an allowlist of column names | high       |

UNAVAILABLE:

- <dimension> — <scanner that was missing or deferred>
```

- `VERDICT: FAIL` iff at least one **blocker** survives.
- Every row cites a taxonomy dimension id — that is how the parent de-duplicates aspects.
- `Location` is `file:line`; line `0` only when a finding genuinely has no line.
- `Confidence` is `high` | `medium` | `low`; a `low` row states what would confirm it.
- Never quote a secret value. Cite `file:line` and the detector's verdict, nothing else.
- One row per finding, sorted blocker → major → minor → nit.
- With no findings, emit the header block with `VERDICT: PASS`, zeroed counts, and `NO FINDINGS`.
- Omit `UNAVAILABLE` when every dimension had its scanner.
- Where a judged finding could have been a rule, append `AUTOMATION: <the rule to encode>`.

---

## 6. Related

| Skill                     | Relationship                                                               |
| :------------------------ | :------------------------------------------------------------------------- |
| `review-beta:start`       | The orchestrator that invokes this aspect and merges its report            |
| `review-beta:correctness` | Owns the same mechanisms where no attacker path exists                     |
| `review-beta:process`     | Owns merge gating, rollout and telemetry; this aspect owns the audit trail |
