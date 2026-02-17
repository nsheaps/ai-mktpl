# gs-stack-status: Migration to TypeScript/Bun Standalone Repo

**Status:** Draft
**Author:** Nathan Heaps
**Created:** 2026-02-17
**Last Updated:** 2026-02-17
**Reviewers:** [TBD]

## 1. Problem Statement

`gs-stack-status.sh` is a ~1,076-line bash script that has grown
organically to handle complex responsibilities: GitHub GraphQL API
queries, terminal rendering across 3 output formats (interactive, osc8,
markdown), watch mode with alternate screen buffers, worktree detection,
column alignment with fullwidth Unicode awareness, deduplication of CI
check runs, and filtering/truncation logic.

Bash is the wrong tool for this level of complexity. The script is
fragile (string-based templating of GraphQL queries, `sed`/regex for
parsing), hard to test (no unit tests, validation requires visual
inspection), and difficult to extend (adding JSON output mode or new
features requires careful quoting gymnastics).

Moving to TypeScript with Bun as the runtime would make the tool
maintainable, testable, and extensible — while keeping it fast (Bun's
startup is ~25ms) and distributable as a single-file executable via
`bun build --compile`.

## 2. Target Users

### Primary Persona

- **Who:** Developers using git-spice for stacked branch workflows
- **Context:** Terminal-based development, managing 3-15+ stacked
  branches with associated PRs, needing at-a-glance stack health
- **Current workaround:** The existing bash script works but is
  unmaintainable and untestable
- **Pain level:** Medium — the tool works today but can't grow safely

### Secondary Personas

- **AI coding agents** — need structured JSON output to understand
  stack state programmatically
- **Contributors** — TypeScript has a much lower contribution barrier
  than a 1000+ line bash script with escape-code rendering

## 3. Goals and Success Metrics

| Metric                  | Current (bash)        | Target (TS/Bun)        | How Measured            |
| ----------------------- | --------------------- | ---------------------- | ----------------------- |
| Code maintainability    | Single 1076-line file | Modular TS codebase    | File count, avg length  |
| Test coverage           | 0%                    | >80% of core logic     | Test runner output      |
| Startup time            | ~200ms (bash+jq+gh)   | <500ms                 | `time gsv`              |
| Feature parity          | Full                  | Full on day 1          | Manual comparison       |
| New feature velocity    | Hours (fragile edits) | Minutes (typed, tested)| Developer experience    |

### Non-Goals

- Rewriting git-spice itself
- Building a TUI/interactive branch manager (watch mode stays passive)
- Supporting non-GitHub forges (initially — same as current script)
- Replacing `gs ls` — this complements it

## 4. Scope

### In Scope

- **Full feature parity** with the current bash script:
  - All 3 output formats (interactive, osc8, markdown)
  - Watch mode with alternate screen buffer
  - Worktree detection and `＋` indicator
  - Column alignment with fullwidth Unicode handling
  - Review status (approved, changes_requested, unreviewed, draft,
    draft+approved)
  - CI status with deduplication and required-check filtering
  - Filtering (--reviewed, --failing-ci, etc.)
  - Truncation (branch names, PR titles)
  - Color/no-color/force-color detection
  - Legend rendering per format
- **New standalone repo** in `nsheaps/gs-stack-status` (or similar)
  following the pattern of `nsheaps/claude-utils` and `nsheaps/git-wt`
- **Bun as runtime and build tool** — `bun build --compile` for
  distributable binary
- **Homebrew formula** for installation (matching existing repos)
- **Unit and integration tests** for core logic
- **JSON output mode** (currently missing from bash script — new feature
  aligning with [gs-branch-viewer spec](./gs-branch-viewer.md) FR-008)

### Out of Scope

- Modifying branches or PRs (read-only tool)
- Supporting GitLab MRs (future consideration)
- Web UI or browser-based view
- Notification/alerting

### Future Considerations

- JSON output mode for agent consumption (from gs-branch-viewer spec)
- GitLab MR support
- Verbose mode with per-check detail
- `tmux` status bar integration
- Publishing to npm (in addition to Homebrew)
- Claude Code plugin wrapping the tool

## 5. Requirements

### Functional Requirements

#### Architecture

| ID     | Requirement                                                       | Priority  | Acceptance Criteria                                          |
| ------ | ----------------------------------------------------------------- | --------- | ------------------------------------------------------------ |
| FR-001 | Modular codebase with clear separation of concerns                | Must-have | Separate modules for: data fetching, rendering, CLI parsing  |
| FR-002 | All current CLI flags supported with identical behavior           | Must-have | `--output`, `--watch`, `--color`, etc. all work as before    |
| FR-003 | Single compiled binary via `bun build --compile`                  | Must-have | `gsv` binary runs without Bun installed                      |
| FR-004 | Homebrew formula for installation                                 | Must-have | `brew install nsheaps/devsetup/gs-stack-status`              |

#### Data Layer

| ID     | Requirement                                                       | Priority    | Acceptance Criteria                                         |
| ------ | ----------------------------------------------------------------- | ----------- | ----------------------------------------------------------- |
| FR-005 | Parse `gs ls --all` output for branch hierarchy                   | Must-have   | Correctly handles all tree characters (┣┏┻┃□■)              |
| FR-006 | Fetch PR metadata via GitHub GraphQL API                          | Must-have   | Single batched query (not N+1) for all PRs in stack         |
| FR-007 | Detect worktree branches via `git worktree list --porcelain`      | Must-have   | Excludes current worktree, marks others                     |
| FR-008 | Deduplicate CI check runs (keep most recent by databaseId)        | Must-have   | No stale check results from workflow re-runs                |
| FR-009 | Support `--only-required-ci` filtering                            | Must-have   | CI status reflects only required checks when enabled        |

#### Rendering

| ID     | Requirement                                                       | Priority    | Acceptance Criteria                                         |
| ------ | ----------------------------------------------------------------- | ----------- | ----------------------------------------------------------- |
| FR-010 | Interactive format with aligned columns                           | Must-have   | Matches current bash output layout                          |
| FR-011 | OSC 8 format with clickable hyperlinks                            | Must-have   | PR URLs and repo name are clickable                         |
| FR-012 | Markdown format with proper indentation                           | Must-have   | Valid markdown, renders correctly on GitHub                  |
| FR-013 | Fullwidth Unicode character width handling                        | Must-have   | `＋` renders correctly at 2 columns                         |
| FR-014 | Color support with NO_COLOR/FORCE_COLOR/TTY detection             | Must-have   | Follows [no-color.org](https://no-color.org) standard       |
| FR-015 | Watch mode using alternate screen buffer                          | Must-have   | No scrollback pollution, "Last updated" timestamp           |
| FR-016 | Worktree indicator (`＋`) and branch name in bold magenta          | Must-have   | Visually distinct from non-worktree branches                |

#### Testing

| ID     | Requirement                                                       | Priority    | Acceptance Criteria                                         |
| ------ | ----------------------------------------------------------------- | ----------- | ----------------------------------------------------------- |
| FR-017 | Unit tests for tree parsing logic                                 | Must-have   | Tests cover all tree characters and edge cases              |
| FR-018 | Unit tests for CI status computation (dedup, required filtering)  | Must-have   | Tests cover all CI state combinations                       |
| FR-019 | Unit tests for column alignment and width calculation             | Must-have   | Tests cover fullwidth chars, truncation, padding            |
| FR-020 | Snapshot tests for each output format                             | Should-have | Regression detection on rendering changes                   |

### Non-Functional Requirements

| ID      | Requirement     | Target                                                      |
| ------- | --------------- | ----------------------------------------------------------- |
| NFR-001 | Startup time    | <500ms for 15 branches including GraphQL call                |
| NFR-002 | Binary size     | <50MB compiled (Bun compiled binaries are ~40-80MB)         |
| NFR-003 | Compatibility   | macOS (arm64, x64) and Linux (x64)                          |
| NFR-004 | Auth            | Uses existing `gh` auth token; no additional setup          |
| NFR-005 | Dependencies    | Minimal — only `gs` and `git` as external runtime deps      |

## 6. Technical Considerations

### Proposed Module Structure

```
gs-stack-status/
├── bin/
│   └── gsv                        # Compiled binary (git-ignored)
├── src/
│   ├── cli.ts                     # Argument parsing (minimist or commander)
│   ├── index.ts                   # Entry point, orchestration
│   ├── data/
│   │   ├── gs-tree.ts             # Parse gs ls output into branch tree
│   │   ├── github-graphql.ts      # Build and execute GraphQL query
│   │   ├── ci-status.ts           # CI status computation with dedup
│   │   ├── review-status.ts       # Review status mapping
│   │   └── worktree.ts            # Worktree detection
│   ├── render/
│   │   ├── interactive.ts         # Interactive terminal format
│   │   ├── osc8.ts                # OSC 8 hyperlink format
│   │   ├── markdown.ts            # Markdown format
│   │   ├── colors.ts              # Color/emoji constants, TTY detection
│   │   ├── alignment.ts           # Column alignment, width calculation
│   │   └── legend.ts              # Legend rendering per format
│   ├── watch.ts                   # Watch mode (alternate screen buffer)
│   └── types.ts                   # Shared type definitions
├── test/
│   ├── data/
│   │   ├── gs-tree.test.ts
│   │   ├── ci-status.test.ts
│   │   └── review-status.test.ts
│   ├── render/
│   │   ├── alignment.test.ts
│   │   └── __snapshots__/
│   └── fixtures/
│       ├── gs-ls-output.txt       # Sample gs ls outputs
│       └── graphql-response.json  # Sample API responses
├── Formula/
│   └── gs-stack-status.rb         # Homebrew formula
├── package.json
├── tsconfig.json
├── bunfig.toml
├── CLAUDE.md
├── README.md
├── LICENSE
└── renovate.json
```

### Key Design Decisions

| Decision                      | Choice                  | Rationale                                                        |
| ----------------------------- | ----------------------- | ---------------------------------------------------------------- |
| Runtime                       | Bun                     | Fast startup (~25ms), built-in TS support, `--compile` for binary |
| No framework for CLI parsing  | `minimist` or built-in  | Simple flags, no subcommands — framework is overkill              |
| GitHub API                    | Direct `fetch` to GraphQL | Avoid `gh` subprocess; use `gh auth token` for auth             |
| Tree parsing                  | Custom parser (from bash) | `gs ls --json` exists but doesn't include all needed metadata   |
| Terminal rendering            | Custom (no framework)   | chalk/kleur add deps; ANSI codes are simple enough              |
| Testing                       | `bun test` (built-in)   | Zero-config, fast, snapshot support                              |

### Migration Strategy

**Phase 1: Port with parity** — Direct translation of bash logic into
TypeScript modules, maintaining identical output. Validate by comparing
output of bash script vs TS tool on the same repo.

**Phase 2: Improve** — Add JSON output, better error messages, and the
features from the [gs-branch-viewer spec](./gs-branch-viewer.md) that
the bash script doesn't have yet.

**Phase 3: Deprecate bash** — Remove `gs-stack-status.sh` from the
git-spice plugin, update all references to point to the new repo.

### Dependencies

- **Bun** >= 1.0 for development and `bun build --compile`
- **git-spice** (`gs`) for branch hierarchy data
- **git** for worktree detection
- **GitHub API** for PR/CI metadata (uses `gh auth token` for auth)

### Differences from gs-branch-viewer Spec

This spec focuses on the **migration** from bash to TypeScript. The
[gs-branch-viewer spec](./gs-branch-viewer.md) covers the broader
product vision (JSON output, verbose mode, short mode, etc.). This
migration spec is Phase 1 — achieving parity — after which the
gs-branch-viewer features can be implemented in the new codebase.

## 7. Open Questions

| #   | Question                                                          | Owner  | Status | Resolution |
| --- | ----------------------------------------------------------------- | ------ | ------ | ---------- |
| 1   | Repo name: `gs-stack-status`, `gsv`, or `git-spice-viewer`?      | Nathan | Open   |            |
| 2   | Use `gh api` subprocess or direct fetch with `gh auth token`?     | Nathan | Open   | Direct fetch is faster but requires token management |
| 3   | Should `gs ls --json` be used instead of parsing text output?     | Nathan | Open   | JSON is cleaner but may not include all tree metadata |
| 4   | Bun compiled binary size acceptable (~50MB)?                      | Nathan | Open   | Compare with Go alternative (~10MB) |
| 5   | Should the Homebrew formula use the compiled binary or require Bun? | Nathan | Open | Compiled binary is more portable |

## 8. Next Steps

1. [ ] Review and approve this spec — Nathan
2. [ ] Create `nsheaps/gs-stack-status` repo with scaffolding
3. [ ] Port tree parsing and test with fixtures
4. [ ] Port GraphQL query builder and CI status logic
5. [ ] Port all 3 renderers with snapshot tests
6. [ ] Port watch mode
7. [ ] Validate output parity with bash script
8. [ ] Add Homebrew formula
9. [ ] Deprecate bash script in git-spice plugin

## 9. References

- [gs-branch-viewer spec](./gs-branch-viewer.md) — Broader product
  vision for the tool
- [Current bash script](../../scripts/gs-stack-status.sh) — Source of
  truth for feature parity
- [nsheaps/claude-utils](https://github.com/nsheaps/claude-utils) —
  Reference repo structure (Homebrew formula, release-it, bin/)
- [nsheaps/git-wt](https://github.com/nsheaps/git-wt) — Reference
  repo structure (same pattern)
- [Bun compiled binaries](https://bun.sh/docs/bundler/executables) —
  `bun build --compile` documentation
- [no-color.org](https://no-color.org) — Color output standard
- [OSC 8 Hyperlinks](https://gist.github.com/egmontkob/eb114294efbcd5adb1944c9f3cb5feda) —
  Terminal hyperlink specification

## Revision History

| Date       | Author       | Changes                                          |
| ---------- | ------------ | ------------------------------------------------ |
| 2026-02-17 | Nathan Heaps | Initial draft — migration spec from bash to Bun/TS |
