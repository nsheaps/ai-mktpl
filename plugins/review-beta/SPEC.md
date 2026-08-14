# Plugin: review-beta

**Purpose**: Multi-aspect code and documentation review. One entry skill decides what kind of review was asked for, delegates to the aspects that apply, and merges what comes back into one verified report.

**Requires**: Claude Code v2.1.218 or later (the aspect skills set `background: false`, which is version-gated).

## Skills

- `start` — "Routing, hard gates, delegation, de-duplication, verification, synthesis" (the entry point; holds no review criteria of its own)
- `correctness` — "Logic, edges, concurrency, data loss, tests"
- `security` — "AppSec, personal data, supply chain"
- `design` — "Abstraction, contracts, coupling, duplication"
- `docs` — "Documentation truth, links, examples, usability"
- `process` — "How the change arrives and rolls out"
- `org-fit` — "Fit with this org's declared assets and rules"
- `best-practices` — "Ecosystem-idiomatic practice, decided by each language's own opinionated linter"
- `agentic-configuration` — "Whether skills, plugin manifests, hooks, agents and commands are well built"

## Scripts

Each aspect ships a probe under `skills/<aspect>/scripts/probe-<aspect>.sh`, which runs that family's tools and emits `SEVERITY|FILE|LINE|DIMENSION|MESSAGE` rows plus `# tool=… status=ran|missing` metadata. `agentic-configuration` additionally ships two checkers, `check-skill.sh` (`SK` ids) and `check-plugin.sh` (`PL`/`HK`/`AG`/`CM` ids).

No hooks, no commands, no MCP servers, no agents.

## Contracts

Three contracts hold this together, and a change that breaks one breaks the plugin:

1. **Aspect discovery.** `start` enumerates its sibling skill directories. A directory is an aspect only if it has a `SKILL.md`, declares `context: fork`, and contains a `## N. Return contract` heading. A directory failing any of the three is reported as unrecognized rather than invoked.
2. **Return shape.** Every aspect returns `SEVERITY|FILE|LINE|DIMENSION|MESSAGE` rows. A literal pipe inside `FILE` or `MESSAGE` is escaped `\|`, so the field count is always five.
3. **No tool, no finding.** A dimension whose tool is absent — or present but unusable — is reported unavailable, never clean. A dimension carries exactly one of `ran` / `missing`.

## Tracked for v0.2

- Capture output fixtures for the `correctness`, `process` and `best-practices` probe filters, **then** extract the ~600 duplicated lines into `probe-common.sh`. Fixtures first: extracting untested filters moves the risk without reducing it.
- One positive fixture per remaining `PL`/`HK`/`AG`/`CM` check id, each with a negative control. The retired `HK001` is the argument — it reported zero across 16 live declarations and the sweep read that zero as precision.
- Apply the `tool_usable()` precondition to the 15 remaining marker-file-guarded probe rows, so a row whose config file is absent reports `missing` rather than `ran`. Best done with the `probe-common.sh` extraction, where the predicate is written once.
- Relay probe provenance across the fork boundary: add each probe's own `# tool=… status=ran dimensions=…` metadata to every aspect's return contract as a `TOOLS:` block, beside `UNAVAILABLE:`. §4's corroboration rule needs to know whether two agreeing aspects ran the same binary, and today only the tools that _did not_ run reach `start`. Until then §4 treats undeterminable provenance as one observation, which fails safe but is a rule without a mechanism. Also makes `COUNTS: (tool=<n> judged=<n>)` auditable.
- Vendor the taxonomy source into the plugin, so the dimension tables have a checked-in origin.
- Consider a `PL007` requiring `SPEC.md`, citing the `plugin-spec-sync` skill — the convention is at 54/57 adoption (this file is one of the 54; the three without are `bash-command-rejection`, `claude-builtins` and `spec-validation`) and is not written down as a rule anywhere.

## Retired check ids

Retired ids are never reused; a stale id in an old report must not resolve to a different rule.

- `HK001` — faulted `PreToolUse` / `PostToolUse` / `PostToolUseFailure` / `PermissionRequest` in a plugin `hooks.json` as silently dead, on a rule recorded in `plugins/CLAUDE.md` from a v2.1.128 confirmation. Retired 2026-08-14 after re-testing on v2.1.231, where a plugin manifest fired `PreToolUse`, `PostToolUse` and `PostToolUseFailure`. See `tests/run-probe-tests.sh` Case 8b, which now asserts the absence of the check.
