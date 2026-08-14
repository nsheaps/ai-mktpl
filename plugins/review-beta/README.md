# review-beta

Multi-aspect code and documentation review. One entry skill decides **what kind** of review was
asked for, delegates to the aspects that apply, and merges what comes back into a single verified
report.

> **Requires Claude Code v2.1.218 or later.** The aspect skills set `background: false`, which is
> version-gated. On an older client the key is ignored, the aspects fork into the background, and
> `start` reaches its synthesis step with nothing returned — producing a confident report over an
> empty finding set rather than an error.

> **Beta.** The aspect skills' criteria are stable; their tool coverage is not. Several probe
> commands are written against tool output shapes that could not be executed here — those are
> called out in each aspect's SKILL.md §1, and an unexpected zero from one of them should be
> confirmed by running the tool directly.

## Usage

Start here, always:

```
Skill(skill: "review-beta:start", args: "<path, diff range, or PR>")
```

`start` is a disambiguator. It emits a routing decision before doing any work — what it thinks
you asked for, which aspects it will run, and which it is deliberately skipping — then invokes
each aspect and synthesizes one report. Invoking an aspect directly is supported but skips the
hard gates, the size-scaling decision, and the record of what went unreviewed.

## Skills

| Skill                               | What it owns                                                                    |
| :---------------------------------- | :------------------------------------------------------------------------------ |
| `review-beta:start`                 | Routing, hard gates, delegation, de-duplication, verification, synthesis        |
| `review-beta:correctness`           | Logic, edges, concurrency, data loss, tests (19 taxonomy dimensions)            |
| `review-beta:security`              | AppSec, personal data, supply chain (24)                                        |
| `review-beta:design`                | Abstraction, contracts, coupling, duplication (13)                              |
| `review-beta:docs`                  | Documentation truth, links, examples, usability (18)                            |
| `review-beta:process`               | How the change arrives and rolls out (18)                                       |
| `review-beta:org-fit`               | Fit with this org's declared assets and rules (16)                              |
| `review-beta:best-practices`        | Ecosystem-idiomatic practice, decided by each language's own opinionated linter |
| `review-beta:agentic-configuration` | Whether skills, plugin manifests, hooks, agents and commands are well built     |

## How it works

Each aspect runs with `context: fork`, so its reading, grepping and tool output never enter the
orchestrator's context — only its report does. Every aspect returns the same shape
(`SEVERITY|FILE|LINE|DIMENSION|MESSAGE` rows behind a `## N. Return contract` heading), which is
what makes merging and de-duplicating mechanical rather than a judgement call.

Two disciplines run through all of it:

- **No tool, no finding.** A dimension whose linter is absent is reported _unavailable_, never
  clean and never eyeballed. A reviewer asked to look for something without a tool will find it
  whether or not it is there.
- **Verify before reporting.** Every P0 and every low-confidence finding gets a refutation attempt
  against the cited `file:line` before it reaches the report. A plausible-but-wrong finding costs
  more than a missed one.

## Adding an aspect

`start` discovers aspects by enumerating its sibling skill directories, so a new one participates
without editing any existing file — provided it proves the contract:

1. a `SKILL.md` in `skills/<aspect>/`
2. `context: fork` in its frontmatter
3. a `## N. Return contract` section

A directory that fails any of the three is not invoked; it is reported in `NOT REVIEWED` as an
unrecognized aspect directory, so a half-built skill is visible rather than silently executed.

## Tests

```sh
sh plugins/review-beta/tests/run-probe-tests.sh
```

36 assertions. The `docs`, `security`, `design` and `org-fit` probes have their output-parsing
filters pinned against real captured tool output (provenance in
[`tests/fixtures/SOURCES.md`](tests/fixtures/SOURCES.md)); `correctness`, `process` and
`best-practices` are currently covered only by a syntax check and a `--list` smoke test, so their
filters are unpinned. Also covered: the pipe-escaping contract, the `org-fit` read-only task guard,
the aspect-discovery gate, two `check-skill.sh` checks (`SK012`'s first-link-on-a-line
regression, and `SK024` with a positive, a compliant and a not-applicable fixture), and
`check-plugin.sh`'s `HK001` against both `hooks.json` nestings plus a silent control.

The remaining `PL`/`HK`/`AG`/`CM` ids have no fixtures yet, and that gap has already cost
something: `HK001` shipped testing the wrong nesting level and reported zero across 16 live
violations in this marketplace, while a 51-plugin sweep read that zero as precision. Run the suite
after changing any probe command, filter or check — a check that no longer matches reports zero
silently, which is worse than the tool being absent.
