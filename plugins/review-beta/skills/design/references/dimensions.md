# Dimensions — `design` family

Extracted verbatim from the canonical review taxonomy
(`.ai-agent-jack/docs/research/review-taxonomy/taxonomy.md`, "Family: design").
Column meanings, the severity rubric and the de-duplication ledger live in that source;
this file carries only this family's table and the citations it depends on.

## Contents

1. [Dimension table](#family-design)
2. [References](#references)

## Family: design

Simplicity vs over-engineering, abstraction, coupling/cohesion, duplication, API and data-contract
compatibility, dependency direction, configuration surface. **13 dimensions.**

| id                                    | name                                          | the question                                                                                                                               | severity | scope | tier      | agent      | automatable-with                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | residual                                                                                             |
| :------------------------------------ | :-------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------- | :------- | :---- | :-------- | :--------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :--------------------------------------------------------------------------------------------------- |
| `design-yagni-speculative-generality` | Speculative generality                        | Does this add a variation point with **zero** inhabitants — no call site, subclass, registration or test double anywhere in the tree?      | minor    | diff  | high      | adjudicate | Semgrep "rule of one" battery annotated with a real reference count from `gopls references` / `go/callgraph` RTA, `ts-morph getReferencingNodes()` + `knip --include duplicates,exports`, `rust-analyzer` LSP references, `vulture`/`rope`[^semgrep][^knip][^vulture][^go-deadcode]. Rules use `pattern-not-inside` to exempt types referenced from any test root, named in a DI/wiring module, or with a declared fake. One extra signal, absorbed from the deleted `design-needless-indirection`: a layer added _in this diff_ with exactly one caller, one callee, and no contract change            | Every finding must name the concrete inhabitant count and the file a second inhabitant would live in |
| `design-wrong-abstraction`            | Premature / wrong DRY                         | Is shared code parameterised by _which caller_ rather than by _what varies_?                                                               | major    | diff  | partial   | judge      | Semgrep boolean-literal-at-every-call-site and parameter-only-drives-a-branch; parameter-count growth + Cognitive Complexity delta from history[^semgrep][^sonar-metrics][^metz][^flagarg]                                                                                                                                                                                                                                                                                                                                                                                                              | Whether the parameter names a real axis of variation                                                 |
| `design-duplication`                  | Duplication (`medium: code \| prose \| fact`) | Does this introduce a second copy — of a token sequence, of a passage of prose, or of an authoritative fact — above the project threshold? | minor    | diff  | high      | adjudicate | One clone-detector run for all three media: PMD CPD (exit 4), jscpd over source **and** `**/*.md`, SonarQube `duplicated_lines_density`, against changed files with a base-branch comparison; markdownlint MD024 for the intra-document prose case[^pmd-cpd][^jscpd][^sonar-metrics][^markdownlint]. For `medium: fact`, an **enumerated** fact-type list only — schema definitions, enum member sets, version constants, default values, generated-file contents — with ≥2 occurrences of which at least one lives in a directory the repo marks generated or authoritative. No free-form literal grep | Which copy is canonical, and whether a clone is the cheaper option[^metz][^goproverbs]               |
| `design-api-surface-minimality`       | Public surface size                           | Is anything public, exported or documented that has no consumer outside its own module?                                                    | major    | diff  | high      | adjudicate | Knip unused exports/types, Go `deadcode` + exported-symbol census, Vulture; Semgrep for public mutable fields and internal return types[^knip][^go-deadcode][^vulture][^semgrep][^bloch]                                                                                                                                                                                                                                                                                                                                                                                                                | Whether an unreferenced export is a deliberate extension point                                       |
| `design-backward-compatibility`       | Published code/RPC contract compatibility     | Does this break a published contract without the version bump and window that contract promises?                                           | blocker  | diff  | very-high | adjudicate | `buf breaking`, `japicmp --semantic-versioning`, `oasdiff breaking`, `cargo-semver-checks`, `api-extractor`[^buf-breaking][^japicmp][^oasdiff][^api-surface-diff]; **Go** `apidiff` + `gorelease`[^apidiff]; **Python** `griffe check <pkg> --against <ref>`[^griffe]; **C/C++** `abi-compliance-checker`/`abidiff`. Each wired as a required check on the release path[^semver][^aip180][^go1compat][^hyrum]                                                                                                                                                                                           | Whether an observable-but-undeclared behaviour has a real dependent                                  |
| `design-data-contract-compatibility`  | Emitted data-contract compatibility           | Does this change an emitted event, log, metric or export payload that a consumer outside this codebase depends on?                         | major    | diff  | high      | adjudicate | Schema-registry compatibility (`buf breaking` / Confluent compatibility mode) run against the **event** schemas, not only the RPC ones[^buf-breaking]; diff of emitted event/field names joined against a consumer registry (dbt `source` columns, dashboard and alert query text exported from Grafana/Looker, partner webhook contracts); metric-name and label diff joined against alert rule expressions via `promtool`[^promtool]                                                                                                                                                                  | Whether an unregistered consumer exists                                                              |
| `design-deprecation-migration`        | Deprecation, migration path & notice          | Given that you meant to remove or replace it — who migrates the callers, over what window, with what documented path?                      | major    | diff  | high      | adjudicate | Deprecation-annotation presence + message-names-replacement + marker age from blame + remaining-caller census; require a migration section and `BREAKING CHANGE:` footer on any API-diff removal[^swe-ch15][^k8s-deprecation][^semver][^conventional-commits]                                                                                                                                                                                                                                                                                                                                           | Whether the window and the migration owner are adequate to the caller census                         |
| `design-dependency-direction`         | Layering & dependency direction               | Does an import cross a declared architectural boundary in the forbidden direction?                                                         | blocker  | diff  | very-high | adjudicate | ArchUnit `layeredArchitecture()`/`onionArchitecture()`, import-linter contracts, dependency-cruiser forbidden rules; Semgrep for one-off import bans where no contract file exists[^archunit][^importlinter][^depcruiser][^semgrep][^cleanarch]                                                                                                                                                                                                                                                                                                                                                         | Only where no contract file exists: whether the boundary is real                                     |
| `design-cohesion-responsibility`      | Cohesion / responsibility count               | Does one unit hold responsibilities that change for different reasons?                                                                     | major    | diff  | partial   | judge      | Shipped implementations, not a described algorithm: PMD `GodClass` (WMC/ATFD/TCC), `TooManyFields`, `TooManyMethods`, `ExcessivePublicCount`, `CouplingBetweenObjects`; `eslint-plugin-sonarjs` + SonarQube `class_complexity`/LCOM4; `radon cc`/`radon mi` + `wily diff`; `gocognit`/`gocyclo` — all reported as deltas against the base branch. Plus the signal absorbed from the deleted `design-coupling-fanout`: a single unit importing symbols from >N unrelated concern-clusters[^sonar-metrics][^refguru-lc]                                                                                   | The proposed split boundary — judged only over units the tool already flagged                        |
| `design-hidden-global-state`          | Hidden global state                           | Does this introduce coupling the import graph cannot see?                                                                                  | major    | diff  | high      | adjudicate | Semgrep: module-scope mutable declarations, singleton accessors, ambient clock/env/rand/IO calls below the composition root; serial-test requirements in test config[^semgrep][^googletest-testable]                                                                                                                                                                                                                                                                                                                                                                                                    | Whether the state is genuinely process-global                                                        |
| `design-testability-seams`            | Substitutable seams                           | Can a collaborator be replaced without editing the unit under test?                                                                        | major    | diff  | high      | adjudicate | Semgrep: work in constructors, construct-in-body, static IO calls, service-locator lookups — scoped with `pattern-not-inside` to exempt the wiring layer[^semgrep][^googletest-testable]                                                                                                                                                                                                                                                                                                                                                                                                                | Whether a seam is worth its indirection here (the opposed pair)                                      |
| `design-configuration-surface`        | Configuration & flag surface                  | Does each new knob have a default, an owner, tests of both states, the right storage location and a removal plan?                          | minor    | diff  | high      | adjudicate | Config-key census cross-joined with env files, manifests, docs and coverage; flag age from blame; expiry "time-bomb" tests[^12factor-config][^fowler-toggles]                                                                                                                                                                                                                                                                                                                                                                                                                                           | Whether the default is the safe one                                                                  |
| `design-third-party-dependency`       | New dependency justification                  | Is a newly added external dependency worth its permanent carrying cost?                                                                    | major    | diff  | high      | adjudicate | Emit a **metric card per added dependency, mechanically, before any agent reads anything**: OpenSSF Scorecard run against the _dependency's own_ repo[^scorecard]; `deps.dev` API for transitive count and advisory status; `npm pack --dry-run`/`du` for installed-size delta; registry API for last-publish date and maintainer count; `socket` CLI or `npq` for install-script and capability flags; SPDX id from the lockfile; dependency-cruiser unlisted / dev-in-prod[^depcruiser][^swe-ch21][^yagni]                                                                                            | One short adjudication over the card: is this capability worth these numbers                         |

Grounded in: [^google-look][^google-std][^yagni][^metz][^flagarg][^refguru-sg][^refguru-mm][^refguru-lc][^bloch][^hyrum][^goproverbs][^cleanarch][^googletest-testable][^12factor-config][^fowler-toggles][^swe-ch15][^swe-ch21][^k8s-deprecation][^semver][^aip180][^go1compat][^go-deadcode][^knip][^vulture][^tsconfig][^pmd-cpd][^jscpd][^sonar-metrics][^markdownlint][^depcruiser][^archunit][^importlinter][^buf-breaking][^japicmp][^oasdiff][^apidiff][^griffe][^api-surface-diff][^promtool][^semgrep]

---

## References

[^12factor-config]: _The Twelve-Factor App_, III. Config — the open-source litmus test. <https://12factor.net/config>

[^aip180]: Google AIP-180, _Backwards compatibility_ — renames, type changes, new required fields, default changes, tightened validation, semantic changes; see also the AIP index <https://google.aip.dev/general>. <https://google.aip.dev/180>

[^api-surface-diff]: Public-surface diffing where no wire schema exists — `cargo-semver-checks` <https://github.com/obi1kenobi/cargo-semver-checks> and Microsoft API Extractor <https://api-extractor.com/>

[^apidiff]: The Go Authors, _`apidiff`_ — determines whether two versions of a package are compatible; paired with `gorelease` for the implied semver bump. <https://pkg.go.dev/golang.org/x/exp/cmd/apidiff>

[^archunit]: ArchUnit User Guide — `layeredArchitecture()`, `onionArchitecture()`, `slices()…beFreeOfCycles()`, `adhereToPlantUmlDiagram()`. <https://www.archunit.org/userguide/html/000_Index.html>

[^bloch]: Joshua Bloch, _How to Design a Good API and Why It Matters_ / InfoQ interview — "When in doubt, leave it out"; "Public APIs, like diamonds, are forever". <https://www.infoq.com/articles/API-Design-Joshua-Bloch/>

[^buf-breaking]: Buf, _Breaking change rules and categories_ — FILE ⊃ PACKAGE ⊃ WIRE_JSON ⊃ WIRE; `FIELD_NO_DELETE`, `FIELD_SAME_TYPE`, `RPC_NO_DELETE`. <https://buf.build/docs/breaking/rules/>

[^cleanarch]: Robert C. Martin, _The Clean Architecture_ — the Dependency Rule. <https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html>

[^conventional-commits]: _Conventional Commits 1.0.0_ — type prefix, `!` and `BREAKING CHANGE:` footer; automatic changelog and SemVer bump. <https://www.conventionalcommits.org/en/v1.0.0/>

[^depcruiser]: dependency-cruiser — circular deps, orphans, forbidden directions, dev-deps-in-production, missing deps. <https://github.com/sverweij/dependency-cruiser>

[^flagarg]: Fowler, _FlagArgument_. <https://martinfowler.com/bliki/FlagArgument.html>

[^fowler-toggles]: Hodgson / Fowler, _Feature Toggles (aka Feature Flags)_ — toggles as inventory with a carrying cost; expiry time-bombs; ops toggles and kill switches. <https://martinfowler.com/articles/feature-toggles.html>

[^go-deadcode]: The Go Blog, _Finding unreachable functions with deadcode_ — Rapid Type Analysis and its soundness gaps. <https://go.dev/blog/deadcode>

[^go1compat]: _Go 1 and the Future of Go Programs_ — the compatibility promise and its enumerated exceptions. <https://go.dev/doc/go1compat>

[^google-look]: Google, _What to Look For in a Code Review_ (eng-practices) — over-engineering as a type of complexity; tests in the same CL; docs updated with behaviour. <https://google.github.io/eng-practices/review/reviewer/looking-for.html>

[^google-std]: Google, _The Standard of Code Review_ (eng-practices) — design is not preference; the style guide is the absolute authority on style. <https://google.github.io/eng-practices/review/reviewer/standard.html>

[^googletest-testable]: Hevery, Google Testing Blog, _Writing Testable Code_ — constructors doing real work, `new`-ing collaborators, statics, singletons and global state, "ask, don't look for". <https://testing.googleblog.com/2008/08/by-miko-hevery-so-you-decided-to.html>

[^goproverbs]: _Go Proverbs_ (Rob Pike) — "The bigger the interface, the weaker the abstraction"; "A little copying is better than a little dependency". <https://go-proverbs.github.io/>

[^griffe]: Griffe — _Checking APIs_: `griffe check <package> -b <new-ref> -a <old-ref>` detects breaking changes between two snapshots of a Python project's public API. <https://mkdocstrings.github.io/griffe/guide/users/checking/>

[^hyrum]: _Hyrum's Law_ — all observable behaviours will be depended on by somebody. <https://www.hyrumslaw.com/>

[^importlinter]: Import Linter — forbidden, protected, layers, independence, acyclic-siblings contracts for Python. <https://import-linter.readthedocs.io/>

[^japicmp]: japicmp — binary vs source compatibility diffing between JAR versions; `--semantic-versioning`. <https://github.com/siom79/japicmp>

[^jscpd]: jscpd — Rabin–Karp clone detection across 220+ formats including Markdown, with CI thresholds. <https://github.com/kucherenko/jscpd>

[^k8s-deprecation]: Kubernetes, _Deprecation Policy_ — announcement, replacement, timeline, release notes; beta/GA/alpha periods; `Warning` header and deprecated-API metric. <https://kubernetes.io/docs/reference/using-api/deprecation-policy/>

[^knip]: Knip — unused files, dependencies, exports, exported types, unlisted dependencies. <https://knip.dev/>

[^markdownlint]: markdownlint, _Rules_ — MD001, MD013, MD024, MD034, MD041, MD043, MD045, MD051, MD052, MD053. <https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md>

[^metz]: Sandi Metz, _The Wrong Abstraction_ — "duplication is far cheaper than the wrong abstraction". <https://sandimetz.com/blog/2016/1/20/the-wrong-abstraction>

[^oasdiff]: oasdiff — OpenAPI diff with a `breaking` command and a GitHub Action. <https://github.com/Tufin/oasdiff>

[^pmd-cpd]: PMD, _Copy-Paste Detector (CPD)_ — token-based clone detection, `--minimum-tokens`, exit code 4 on duplication. <https://docs.pmd-code.org/latest/pmd_userdocs_cpd.html>

[^promtool]: Prometheus, _Unit Testing for Rules_ — `promtool test rules`, `alert_rule_test` asserting labels and annotations. <https://prometheus.io/docs/prometheus/latest/configuration/unit_testing_rules/>

[^refguru-lc]: Refactoring.Guru, _Large Class_ — Extract Class/Subclass/Interface. <https://refactoring.guru/smells/large-class>

[^refguru-mm]: Refactoring.Guru, _Middle Man_ — delegation-only classes; the Proxy/Decorator exception. <https://refactoring.guru/smells/middle-man>

[^refguru-sg]: Refactoring.Guru, _Speculative Generality_ — signs, causes, treatments, framework exception. <https://refactoring.guru/smells/speculative-generality>

[^scorecard]: OpenSSF Scorecard — `Pinned-Dependencies`, `Vulnerabilities`, `Maintained`, `Dependency-Update-Tool`, `Token-Permissions`, `Dangerous-Workflow`, `Signed-Releases`, `Packaging`. <https://securityscorecards.dev/>

[^semgrep]: Semgrep — _Writing rules_ (`patterns`, `pattern-not`, `pattern-inside`, metavariables) and _Taint mode_ (sources, sinks, sanitizers, propagators). <https://docs.semgrep.dev/writing-rules/overview> · <https://docs.semgrep.dev/writing-rules/data-flow/taint-mode/overview>

[^semver]: _Semantic Versioning 2.0.0_ — MAJOR/MINOR/PATCH rules; public-API declaration; released contents MUST NOT be modified; deprecation procedure. <https://semver.org/>

[^sonar-metrics]: SonarQube Server, _Metric definitions_ — Cognitive Complexity, Cyclomatic Complexity, class complexity, duplication thresholds, `duplicated_lines_density`. <https://docs.sonarsource.com/sonarqube-server/user-guide/code-metrics/metrics-definition.md>

[^swe-ch15]: _Software Engineering at Google_, Ch. 15 "Deprecation" — advisory vs compulsory; "Code is a liability, not an asset"; the team removing the old system owns the migration. <https://abseil.io/resources/swe-book/html/ch15.html>

[^swe-ch21]: _Software Engineering at Google_, Ch. 21 "Dependency Management" — the import checklist; prefer source-control problems over dependency-management problems. <https://abseil.io/resources/swe-book/html/ch21.html>

[^tsconfig]: TypeScript, _TSConfig Reference_ — `strictNullChecks`, `noUnusedLocals`, `noUnusedParameters`. <https://www.typescriptlang.org/tsconfig/>

[^vulture]: Vulture — unused code and unreachable statements for Python, with confidence levels and whitelists. <https://github.com/jendrikseipp/vulture>

[^yagni]: Fowler, _Yagni_ — cost of build/delay/carry/repair; testability effort is out of scope. <https://martinfowler.com/bliki/Yagni.html>
