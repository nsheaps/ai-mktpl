# Dimensions — `best-practices` family

**This family is not in the canonical taxonomy.** The other seven aspects draw their dimensions
from an internal source not shipped with this plugin
(`.ai-agent-jack/docs/research/review-taxonomy/taxonomy.md`), whose 108 dimensions are partitioned
across six families —
none of which is "best practices". That is deliberate on the taxonomy's part: "follows best
practice" is not a reviewable property on its own, because without a named rule it collapses into
the reviewer's taste.

This family exists anyway, for one narrow reason: every major ecosystem publishes an opinionated
linter whose maintainers already decided what idiomatic means in that language. Those rule
catalogues are a real, citable standard. So each dimension below is defined **as** a linter, and a
finding in this family is always that linter's finding, never an unbacked judgement.

The consequence, stated plainly: **a language whose linter is not installed has no coverage here.**
It is reported unavailable. There is no fallback to reading the diff and forming an opinion.

## Dimension table

| id                   | ecosystem | tool            | severity ceiling | rule catalogue                                                                                                                                                                |
| :------------------- | :-------- | :-------------- | :--------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bp-go-idiom`        | Go        | `golangci-lint` | major            | <https://golangci-lint.run/usage/linters/>                                                                                                                                    |
| `bp-rust-idiom`      | Rust      | `cargo clippy`  | major            | <https://rust-lang.github.io/rust-clippy/master/>                                                                                                                             |
| `bp-python-idiom`    | Python    | `ruff`          | major            | <https://docs.astral.sh/ruff/rules/>                                                                                                                                          |
| `bp-js-idiom`        | JS/TS     | `biome`         | major            | <https://biomejs.dev/linter/rules/>                                                                                                                                           |
| `bp-ruby-idiom`      | Ruby      | `rubocop`       | major            | <https://docs.rubocop.org/rubocop/cops.html>                                                                                                                                  |
| `bp-css-idiom`       | CSS/SCSS  | `stylelint`     | nit              | <https://stylelint.io/user-guide/rules>                                                                                                                                       |
| `bp-swift-idiom`     | Swift     | `swiftlint`     | major            | <https://realm.github.io/SwiftLint/rule-directory.html>                                                                                                                       |
| `bp-kotlin-idiom`    | Kotlin    | `ktlint`        | major            | <https://pinterest.github.io/ktlint/latest/rules/standard/>                                                                                                                   |
| `bp-terraform-idiom` | Terraform | `tflint`        | major            | <https://github.com/terraform-linters/tflint/tree/master/docs/rules>                                                                                                          |
| `bp-php-idiom`       | PHP       | `phpcs`         | major            | <https://github.com/PHPCSStandards/PHP_CodeSniffer>                                                                                                                           |
| `bp-framework-idiom` | any       | —               | major            | **Deferred.** Framework rule packs vary per project and are not discoverable from the tree; enable them in the repo's own linter config and they arrive through the row above |

No dimension here carries a `blocker` ceiling. Unidiomatic code is not an outage; a finding that
feels like one belongs to `correctness` or `security`.

## Why these tools and not others

Each row is the linter the ecosystem itself treats as the idiom authority — the one whose default
rule set ships opinions rather than only error detection. Tools that detect _defects_ rather than
_idiom_ live in other aspects, and running them twice would produce duplicate findings the
orchestrator has to merge away:

| Tool                         | Aspect that owns it       | Why not here                                       |
| :--------------------------- | :------------------------ | :------------------------------------------------- |
| `eslint`, `shellcheck`       | `review-beta:org-fit`     | Configured per-org; the config is the house style  |
| `go vet`, `tsc`, `mypy`      | `review-beta:correctness` | Type and soundness errors, not idiom               |
| `semgrep`                    | `review-beta:correctness` | Pattern-matched defects                            |
| `jscpd`, `knip`              | `review-beta:design`      | Duplication and dead surface are structural        |
| `prettier`, `gofmt`, `black` | the hard gates            | Formatters are decided by the repo's `format` task |

## Overlap with `org-fit`

Where an org has adopted one of the tools above **and checked in its own config**, the finding is
still reported here — the rule is the ecosystem's, and the config only narrows it. `org-fit` owns
conventions the org wrote itself (naming schemes, directory layout, mandated libraries), which no
published catalogue covers. When both aspects report the same `file:line` with different ids, the
parent keeps both rows: same location, different ids is not a duplicate.
