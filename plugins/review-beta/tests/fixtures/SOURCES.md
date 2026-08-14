# Fixture provenance

## Contents

1. [How these were produced](#how-these-were-produced)
2. [Fixture table](#fixture-table)
3. [Formats still unverified](#formats-still-unverified)

## How these were produced

Every fixture in this directory is **real output from the named tool at the named version**,
captured by running that tool against a deliberately defective sample tree (a workflow with
`pull_request_target` plus unpinned and interpolated steps, a markdown file with a dead relative
link and a bare URL, two near-identical JS modules, an unused Python module, a `shell=True`
subprocess call, and a `requirements.txt` pinned to known-vulnerable releases).

Nothing here is hand-written. A fabricated fixture manufactures false confidence: it proves the
parser handles the format the author imagined, which is the same assumption the test exists to
check. If a tool could not be run, its format is listed as unverified below rather than invented.

Regenerating: install the tool at the pinned version, rebuild an equivalent defective tree, and
re-capture. The tests assert on parsed `FILE`/`LINE` values, not on byte equality, so a newer
version with cosmetic changes will still pass — and a version that changes its output _shape_ will
fail, which is the signal worth having.

## Fixture table

| Fixture                 | Tool @ version           | Invocation captured                                         | Shape the parser must handle                                                |
| :---------------------- | :----------------------- | :---------------------------------------------------------- | :-------------------------------------------------------------------------- |
| `semgrep.vim.txt`       | semgrep 1.x              | `semgrep scan --quiet --metrics=off --config <rules> --vim` | `file:line:col:sev:rule:message`                                            |
| `actionlint.txt`        | actionlint 1.7.7         | `actionlint`                                                | `file:line:col: message [rule]`, plus indented source-echo lines            |
| `zizmor.plain.txt`      | zizmor 1.11.0            | `zizmor --offline --format plain .github/workflows`         | rustc-style: `warning[rule]: msg` then ` --> file:line:col` on a later line |
| `lychee.txt`            | lychee 0.18.1            | `lychee --no-progress --offline .`                          | `[ERROR] <url> \| <reason>` — no line numbers at all                        |
| `markdownlint-cli2.txt` | markdownlint-cli2 0.23.2 | `markdownlint-cli2 '**/*.md'`                               | both `file:line error ...` and `file:line:col error ...`                    |
| `cspell.txt`            | cspell 9.x               | `cspell '**/*.md' --no-progress --no-summary`               | `file:line:col - message`                                                   |
| `vulture.txt`           | vulture 2.16             | `vulture . --min-confidence 60`                             | `file:line: message` — line then space, no column                           |
| `jscpd.consolefull.txt` | jscpd 4.x                | `jscpd --reporters consoleFull --min-tokens 50`             | `- file [startLine:col - endLine:col]` then an indented source block        |
| `osv-scanner.txt`       | osv-scanner 2.2.2        | `osv-scanner scan source --lockfile requirements.txt`       | markdown table rows beginning `\| https://osv.dev/<ID>`                     |
| `battery.sarif`         | SARIF 2.1.0              | hand-assembled from the OASIS SARIF 2.1.0 schema shape      | only its **presence** is tested, never its contents — see below             |

Five of these disagreed with what the probes originally assumed, and each disagreement was a silent
zero-findings bug rather than a crash. That is the whole reason this directory exists:

| Tool             | Probe assumed                  | Tool actually emits                            |
| :--------------- | :----------------------------- | :--------------------------------------------- |
| lychee           | `[ERR]`, and "Errors in"       | `[ERROR]`, and "Issues found in N inputs"      |
| zizmor           | `file.yml:line:` at line start | the location on a separate `-->` line          |
| semgrep `--text` | `file:line:` at line start     | a box-drawing summary with no parseable prefix |
| osv-scanner      | rows starting `GHSA`/`CVE`     | rows starting `\| https://osv.dev/<ID>`        |
| jscpd `--silent` | `- ` rows                      | `--silent` suppresses the clone rows entirely  |

A sixth was found by running rather than by reading: `osv-scanner scan source -r .` began a
filesystem walk from `/` and did not return within 200s. The probe now scans only the lockfiles
present in the repo.

## Formats still unverified

These tools could not be installed or run in this environment, so their output shape remains an
assumption. Each is marked unverified in its owning skill rather than presented as covered:

| Tool                                                                              | Owning probe     | Why not verified                        |
| :-------------------------------------------------------------------------------- | :--------------- | :-------------------------------------- |
| trufflehog, gitleaks, secretlint                                                  | `probe-security` | not installable here                    |
| grype, trivy, checkov, kics, syft                                                 | `probe-security` | not installable here                    |
| knip, depcruise, lint-imports, cargo-semver-checks, buf, oasdiff, gocognit, radon | `probe-design`   | not installable here                    |
| vale, interrogate, mkdocs, pytest --doctest                                       | `probe-docs`     | not installable here                    |
| commitlint, semantic-release, `gh pr checks`                                      | `probe-process`  | not installable / needs GitHub API auth |
| syncpack, editorconfig-checker, `go mod tidy`                                     | `probe-org-fit`  | not installable here                    |

`battery.sarif` is a special case: the probes only test for the file's **existence** to decide
whether to defer to CI, and never parse it, so a schema-shaped fixture is sufficient to exercise
that path honestly. Partitioning SARIF by dimension is the aggregator's job and is not implemented
here.

## Synthetic fixtures

One fixture is **not** captured from a tool and is labelled as such, because it tests this
family's own parser rather than any tool's format:

| Fixture                         | What it is                                                                           |
| :------------------------------ | :----------------------------------------------------------------------------------- |
| `synthetic-pipe-in-message.txt` | A markdownlint-shaped diagnostic whose message text contains literal `\|` characters |

It exists to pin the field-count guarantee of the probe output contract: a `|` inside a
diagnostic must not shift the downstream fields. It makes no claim about how markdownlint
actually renders that rule's message.
