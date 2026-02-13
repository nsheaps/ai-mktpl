# gs-branch-viewer

**Status:** Draft
**Author:** Nathan Heaps
**Created:** 2026-02-13
**Last Updated:** 2026-02-13
**Reviewers:** \[TBD\]

## 1. Problem Statement

git-spice (`gs`) is a powerful tool for managing stacked Git branches. Its
`gs log short` (alias `gs ls`) command shows branch hierarchy and PR/CR
status, and `gs log long` (`gs ll`) adds per-branch commits. Both support
`--json` output and `--all` to show every stack.

However, git-spice **does not track or display**:

* CI/build status per branch
* PR review status (approved, changes requested, reviewer assignments)
* Labels, milestones, or other GitHub metadata

Developers working with stacks of 3-10+ branches must cross-reference
`gs ls`, `gh pr list`, and the GitHub UI to build a complete picture of
their stack's health. This context-switching adds up significantly across
a day of stack-based development.

**gs-branch-viewer** is a standalone companion tool that reads git-spice's
`gs ls --json` output, enriches it with GitHub API data (CI status, review
state), and presents a single richly-formatted terminal view with color
coding, emoji indicators, and clickable links.

## 2. Target Users

### Primary Persona

* **Who:** Developers using git-spice for stacked branch workflows
* **Context:** Working in terminal, managing 3-10+ stacked branches with
  associated PRs, needing quick status overview
* **Current workaround:** Running `gs ls -Sa`, then `gh pr list`, then
  checking GitHub UI for review/CI status separately
* **Pain level:** Medium-High -- the friction compounds across every
  stack interaction throughout the day

### Secondary Persona(s)

* **AI coding agents** using git-spice with worktrees for parallel branch
  work -- need structured (JSON) output to programmatically understand
  stack state including CI and review status
* **Team leads** reviewing the state of a developer's stack during pairing
  or review sessions

## 3. Goals and Success Metrics

| Metric | Current Baseline | Target | How Measured |
|----|----|----|----|
| Time to get full stack status | 30-60s (multi-tool) | <3s (single cmd) | User timing |
| Context switches for stack state | 3+ tools | 1 command | Workflow observation |
| Agent stack comprehension | Manual parsing needed | JSON parse, 1 call | Agent integration tests |

### Non-Goals

* Replacing git-spice's core branch management commands
* Modifying git-spice internals or contributing changes upstream (initially)
* Building a TUI/interactive branch manager (watch mode is passive, not
  interactive)
* Supporting non-git-spice branch workflows

## 4. Scope

### In Scope

* Branch listing with stack hierarchy visualization (from `gs ls --json`)
* PR/CR linking with status indicators (from git-spice CR data)
* Review status display: approved, changes requested, pending, draft
  (from GitHub API)
* CI/build status display per branch (from GitHub API)
* Color-coded output with terminal awareness (no color when piped)
* Emoji indicators for status at a glance
* JSON output mode for programmatic consumption (enriched beyond `gs ls`)
* Watch mode for continuous monitoring
* iTerm2 OSC 8 hyperlink support (clickable PR numbers instead of full URLs)
* Configurable verbosity levels (`-s` short, default, `-V` verbose, `-a` all)

### Out of Scope

* Modifying branches or PRs (read-only tool)
* Supporting forges other than GitHub (initially)
* Web UI or browser-based view
* Notification/alerting system
* Replacing `gs ls` -- this complements it

### Future Considerations

* GitLab MR support (git-spice already supports GitLab)
* Slack/webhook integration for stack status changes
* `tmux` status bar integration
* Branch dependency graph visualization (beyond linear stacks)
* Upstream contribution to git-spice if the feature proves valuable

## 5. Requirements

### Functional Requirements

#### Core Display

| ID | Requirement | Priority | Acceptance Criteria |
|----|----|----|----|
| FR-001 | Display branch names with stack hierarchy indentation | Must-have | Stack parent/child relationships are visually clear |
| FR-002 | Show PR/CR number and link for each branch | Must-have | PR number displayed, clickable in iTerm2 |
| FR-003 | Show PR review status (approved, changes requested, pending, draft) | Must-have | Status matches GitHub state |
| FR-004 | Show CI/build status per branch | Must-have | Green/red/yellow/pending indicator matches GitHub checks |
| FR-005 | Color-code output based on status | Must-have | Intuitive colors; no color when stdout is not a TTY |
| FR-006 | Use emoji indicators for quick scanning | Should-have | Configurable on/off; sensible defaults |
| FR-007 | Show PR title in default and verbose views | Must-have | Title displayed after PR number |

#### Output Modes

| ID | Requirement | Priority | Acceptance Criteria |
|----|----|----|----|
| FR-008 | JSON output mode (`--json` or `-j`) | Must-have | Valid JSON; includes all displayed fields plus raw data |
| FR-009 | Short mode (`-s`) showing minimal info | Should-have | Branch name + status emoji only |
| FR-010 | Verbose mode (`-V`) showing extra detail | Should-have | Includes commit counts, last updated, PR description |
| FR-011 | All-branches mode (`-a`) including merged/closed | Should-have | Shows full history with status |

#### Terminal Awareness

| ID | Requirement | Priority | Acceptance Criteria |
|----|----|----|----|
| FR-012 | Detect TTY and suppress colors when piped | Must-have | `gsv | cat` produces plain text |
| FR-013 | iTerm2 OSC 8 hyperlink support for PR URLs | Should-have | PR numbers are clickable hyperlinks in iTerm2 |
| FR-014 | Respect `NO_COLOR` and `FORCE_COLOR` env vars | Must-have | Follows [no-color.org](https://no-color.org) standard |
| FR-015 | Configurable via git config (`spice.viewer.*` keys) | Nice-to-have | Defaults overridable without flags |

#### Watch Mode

| ID | Requirement | Priority | Acceptance Criteria |
|----|----|----|----|
| FR-016 | Watch mode (`-w` or `--watch`) with auto-refresh | Should-have | Refreshes on configurable interval (default 30s) |
| FR-017 | Watch mode detects changes and highlights updates | Nice-to-have | Changed fields flash or are marked with indicator |

#### Script / MVP Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|----|----|----|
| FR-018 | Provide a shell script (`gsv`) that fetches and formats PR information for stacked branches | Must-have | Script runs successfully and produces formatted output |
| FR-019 | Show per-branch: PR number, title (with emojis if present), URL, review status, draft status, stack position | Must-have | All fields populated for each branch with a PR |
| FR-020 | Support single-stack mode (current stack) and all-stacks mode (`-a` flag) | Must-have | Default shows current stack; `-a` shows all stacks |
| FR-021 | Provide `--json` flag for machine-readable output | Must-have | Valid JSON array with consistent schema per branch |
| FR-022 | Callable by Claude Code agents (no interactive prompts, stable output format) | Must-have | Script exits cleanly in non-TTY environments |

### Non-Functional Requirements

| ID | Requirement | Target |
|----|----|----|
| NFR-001 | Performance | Initial listing <5s for stacks of 10 branches |
| NFR-002 | Performance | Watch mode refresh <3s including API calls |
| NFR-003 | Compatibility | Works on macOS and Linux terminals |
| NFR-004 | Compatibility | Degrades gracefully in terminals without emoji/link support |
| NFR-005 | Auth | Uses existing `gh` auth; no additional token setup required |
| NFR-006 | No external dependencies | Only requires `gs`, `gh`, `jq`, and standard POSIX tools |

## 6. User Stories

### Epic: Core Branch Viewing

#### Story 1: View stack with enriched status

**As a** developer using git-spice, **I want to** see my branch stack with
PR review and CI status in a single command **so that** I know which
branches need attention without leaving the terminal.

**Acceptance Criteria:**

* Given a repo with a git-spice stack, when I run `gsv`, then I see
  branch hierarchy with PR numbers, review status, and CI status
* Given a branch with a failing CI check, when I run `gsv`, then that
  branch shows a red indicator and the failing check name
* Given a branch with an approved PR, when I run `gsv`, then that
  branch shows a green checkmark for review status

**Priority:** Must-have
**Estimated Effort:** L

#### Story 2: Machine-readable output for agents

**As an** AI coding agent, **I want to** get enriched stack data as JSON
**so that** I can programmatically decide which branch to work on next.

**Acceptance Criteria:**

* Given a stack, when I run `gsv --json`, then I get valid JSON with
  branch hierarchy, PR data, review status, and CI status
* Given JSON output, when I parse it, then every branch has consistent
  fields (null for missing data, not absent keys)

**Priority:** Must-have
**Estimated Effort:** M

#### Story 3: Quick glance in short mode

**As a** developer, **I want to** get a minimal one-line-per-branch
overview **so that** I can scan stack health at a glance.

**Acceptance Criteria:**

* Given a stack, when I run `gsv -s`, then each branch is one line with
  name + emoji status indicators
* Given short mode, when output is piped, then emojis are replaced with
  text indicators

**Priority:** Should-have
**Estimated Effort:** S

#### Story 4: Clickable PR links in iTerm2

**As a** developer using iTerm2, **I want to** click on PR numbers to open
them in my browser **so that** I can quickly jump to a PR for review.

**Acceptance Criteria:**

* Given iTerm2, when `gsv` displays a PR number, then the number is an
  OSC 8 hyperlink to the PR URL
* Given a non-iTerm2 terminal, when `gsv` displays a PR number, then it
  shows as plain text (graceful degradation)

**Priority:** Should-have
**Estimated Effort:** S

### Epic: Monitoring

#### Story 5: Watch mode for review waiting

**As a** developer waiting for reviews, **I want to** monitor my stack
continuously **so that** I notice when reviews or CI complete.

**Acceptance Criteria:**

* Given `gsv -w`, when a PR receives a review, then the display updates
  on the next refresh cycle
* Given watch mode, when I press `q` or `Ctrl+C`, then it exits cleanly
* Given `gsv -w --interval 10`, then it refreshes every 10 seconds

**Priority:** Should-have
**Estimated Effort:** M

## 7. User Flows

### Flow 1: Quick Stack Status Check

1. Developer runs `gsv` in their repo
2. Tool runs `gs ls --json -Sa` to get stack data from git-spice
3. Tool calls GitHub API (via `gh`) for PR review status and CI checks
4. Tool renders enriched, color-coded branch tree
5. Developer identifies which branch needs attention

### Flow 2: Agent Stack Comprehension

1. AI agent runs `gsv --json`
2. Tool returns enriched JSON with branch/PR/CI/review data
3. Agent parses JSON to understand stack state
4. Agent makes decisions about which branch to work on

### Flow 3: Monitoring During Review

1. Developer runs `gsv -Vw` (verbose + watch)
2. Tool displays detailed stack info, refreshes every 30s
3. Developer sees review approvals and CI status update in real-time
4. Developer proceeds when all checks pass

## 8. Technical Considerations

### Data Pipeline

```
gs ls --json -Sa  -->  Parse branch/CR data
                            |
                            v
                  gh api (GraphQL)  -->  Enrich with:
                            |            - CI check status
                            |            - Review status
                            |            - Reviewer names
                            v
                  Format + Render  -->  Terminal output
                            |            or JSON output
                            v
                  (Watch: loop with interval)
```

### Dependencies

* **git-spice** (`gs`) >= 0.18.0 for `--json` support
* **GitHub CLI** (`gh`) for authentication and API access
* **jq** for JSON processing in the shell script MVP
* **git** for local branch state

### Constraints

* Must work alongside git-spice without conflicting
* Should not require additional authentication beyond what `gh` provides
* Performance constrained by GitHub API rate limits (especially in watch
  mode -- consider caching and conditional requests with ETags)
* `gs ls --json` output format is not formally versioned; may need to
  handle schema changes gracefully

### Architecture Decision

**Phase 1 (MVP): Shell script (`gsv`)**

A shell script that:
1. Runs `gs ls --json` (with optional `-a` for all stacks)
2. Extracts PR numbers from the JSON output
3. Batch-fetches PR details via `gh pr view --json` for each PR
4. Merges stack structure with PR details
5. Formats output for terminal (human) or JSON (agent) consumption

**Phase 2 (Future): Standalone Go binary (`gsv`)**

| Option | Pros | Cons |
|----|----|----|----|
| Go binary | Aligns with git-spice ecosystem; fast; single binary distribution; potential upstream contribution | Heavier for prototyping |
| Shell script | Quick to prototype; easy to iterate | Hard to maintain; fragile parsing; no color library |
| Rust binary | Great CLI ergonomics (clap); fast | Different ecosystem from git-spice |

Go is recommended for Phase 2 because:

1. git-spice is written in Go -- potential to upstream later
2. Libraries like [charmbracelet/lipgloss](https://github.com/charmbracelet/lipgloss)
   provide excellent terminal rendering
3. Single binary distribution (no runtime dependencies)
4. Good JSON parsing and HTTP client in stdlib

### Terminal Rendering

* Use [OSC 8](https://gist.github.com/egmontkob/eb114294efbcd5adb1944c9f3cb5feda)
  escape sequences for hyperlinks (supported by iTerm2, many modern terminals)
* Detect terminal capabilities via `$TERM_PROGRAM` for iTerm2-specific features
* Use `$NO_COLOR` / `$FORCE_COLOR` / isatty check for color decisions

## 9. CLI Usage (MVP Script)

### Installation

Place the `gsv` script on your `$PATH`:

```bash
# From the plugin directory
ln -s /path/to/plugins/git-spice/bin/gsv ~/bin/gsv
# or
cp /path/to/plugins/git-spice/bin/gsv /usr/local/bin/gsv
```

### Usage

```
gsv [OPTIONS]

Options:
  -a, --all          Show all stacks (not just the current one)
  -s, --short        Short mode: one line per branch with status indicators
  -j, --json         Output enriched data as JSON (for agent consumption)
  -h, --help         Show help message

Examples:
  gsv                # Show current stack with PR status
  gsv -a             # Show all stacks
  gsv --json         # JSON output for agents
  gsv -a --json      # All stacks as JSON
  gsv -s             # Short/compact view
```

### Output Fields Per Branch

| Field | Human View | JSON Key | Description |
|-------|-----------|----------|-------------|
| Stack position | Tree indentation | `stackPosition` | Parent-child nesting in the stack |
| Branch name | Branch name text | `name` | git branch name |
| PR number | `#142` | `pr.number` | GitHub PR number |
| PR title | Title text with emojis | `pr.title` | PR title as authored |
| PR URL | Clickable link (iTerm2) or plain text | `pr.url` | Full GitHub PR URL |
| Draft status | `[draft]` indicator | `pr.isDraft` | Whether the PR is a draft |
| Review status | Emoji indicator | `pr.reviewDecision` | `APPROVED`, `CHANGES_REQUESTED`, `REVIEW_REQUIRED`, or empty |
| CI status | Emoji indicator | `ci.state` | Overall CI pass/fail/pending |
| Current branch | `*` marker | `isCurrent` | Whether this is the checked-out branch |

### Agent Integration

Claude Code agents can invoke `gsv --json` and parse the structured output:

```bash
# Agent gets structured stack data in a single call
gsv --json > /tmp/stack-status.json
# Then parse with jq or programmatic JSON tools
jq '.[] | select(.pr.reviewDecision == "APPROVED")' /tmp/stack-status.json
```

The script:
- Requires no interactive input (no TTY needed)
- Exits with code 0 on success, non-zero on failure
- Writes to stdout only (errors to stderr)
- Produces stable JSON schema suitable for programmatic parsing

## 10. Open Questions

| # | Question | Owner | Status | Resolution |
|----|----|----|----|----|
| 1 | Should this be a standalone tool or a git-spice extension/plugin? | Nathan | Resolved | Standalone binary (`gsv`) that reads `gs ls --json` -- can evaluate upstream contribution later |
| 2 | Can git-spice expose internal state (tracked branches, PR IDs) via API? | Nathan | Resolved | Yes, `gs ls --json` provides branch hierarchy and CR metadata since v0.18.0 |
| 3 | What's the best way to get CI status -- `gh` CLI or direct API? | Nathan | Open | Leaning toward `gh api` (GraphQL) for batch efficiency |
| 4 | Should watch mode use filesystem events or polling? | Nathan | Resolved | Polling with configurable interval -- filesystem events wouldn't catch remote state changes |
| 5 | Is there an existing git-spice issue/RFC for enhanced listing? | Nathan | Open |    |
| 6 | What's the right invocation name? | Nathan | Open | Candidates: `gsv` (git-spice viewer), `gs-view`, `gslv` |
| 7 | How to handle GitHub API rate limiting in watch mode? | Nathan | Open | Consider ETags / conditional requests / caching |
| 8 | Should Phase 1 script use `gh pr view` per-PR or batch via GraphQL? | Nathan | Open | Per-PR is simpler; GraphQL is faster for large stacks |

## 11. Next Steps

1. Implement Phase 1 MVP shell script (`gsv`) with basic formatting
2. Test with real stacks (current repo has 14+ stacked branches)
3. Iterate on output format based on daily usage
4. Add JSON output mode for agent integration
5. Evaluate Phase 2 Go binary based on MVP learnings

## 12. References

* [git-spice documentation](https://abhinav.github.io/git-spice/)
* [git-spice GitHub repo](https://github.com/abhinav/git-spice)
* [git-spice CLI reference](https://abhinav.github.io/git-spice/cli/reference/) -
  `gs log short`, `gs log long` command docs
* [git-spice configuration](https://abhinav.github.io/git-spice/cli/config/) -
  `spice.log.*` configuration keys
* [GitHub CLI Manual](https://cli.github.com/manual/) - `gh pr list`, `gh pr view`
* [no-color.org](https://no-color.org) - Color output standard
* [OSC 8 Hyperlinks](https://gist.github.com/egmontkob/eb114294efbcd5adb1944c9f3cb5feda) -
  Terminal hyperlink specification
* [iTerm2 Escape Codes](https://iterm2.com/documentation-escape-codes.html) -
  iTerm2-specific features
* [charmbracelet/lipgloss](https://github.com/charmbracelet/lipgloss) -
  Go terminal rendering library
* [INVEST Criteria](https://en.wikipedia.org/wiki/INVEST_(mnemonic)) -
  User story quality
* `references/pr-status-and-stack-views.md` - Supplemental reference on
  combining `gs ls` with `gh pr view` for rich stack views

## Appendix: Output Mockups

### Default View (`gsv`)

```
 main
 +-- feat/auth-middleware        #142 ✅ 🟢  Add JWT authentication middleware
 |   +-- feat/auth-tests         #143 💬 🟡  Add auth integration tests
 |   +-- feat/auth-docs          #144 ⏳ 🟢  Document auth API endpoints
 +-- fix/rate-limiter            #145 ✅ 🔴  Fix rate limiter token bucket overflow
```

### Short View (`gsv -s`)

```
 feat/auth-middleware  ✅🟢  feat/auth-tests  💬🟡  feat/auth-docs  ⏳🟢  fix/rate-limiter  ✅🔴
```

### Verbose View (`gsv -V`)

```
 main
 +-- feat/auth-middleware        #142 ✅ 🟢
 |   PR: Add JWT authentication middleware
 |   Reviews: @alice ✅  @bob ✅  (2/2 approved)
 |   CI: build ✅  test ✅  lint ✅  (3/3 passing)
 |   Updated: 2h ago  |  +3 commits ahead of main
 |
 |   +-- feat/auth-tests         #143 💬 🟡
 |   |   PR: Add auth integration tests
 |   |   Reviews: @alice 💬 changes requested
 |   |   CI: build ✅  test 🟡 running  (1/2)
 |   |   Updated: 30m ago  |  +2 commits ahead of feat/auth-middleware
 |   |
 |   +-- feat/auth-docs          #144 ⏳ 🟢
 |       PR: Document auth API endpoints
 |       Reviews: awaiting review
 |       CI: build ✅  test ✅  (2/2 passing)
 |       Updated: 1h ago  |  +1 commit ahead of feat/auth-middleware
 |
 +-- fix/rate-limiter            #145 ✅ 🔴
     PR: Fix rate limiter token bucket overflow
     Reviews: @carol ✅  (1/1 approved)
     CI: build ✅  test 🔴 failed  lint ✅  (2/3 passing)
     Updated: 4h ago  |  +1 commit ahead of main
```

### JSON Output (`gsv --json`)

```json
[
  {
    "name": "feat/auth-middleware",
    "base": "main",
    "isCurrent": false,
    "stackPosition": { "depth": 1, "parent": "main", "children": ["feat/auth-tests", "feat/auth-docs"] },
    "pr": {
      "number": 142,
      "url": "https://github.com/org/repo/pull/142",
      "title": "Add JWT authentication middleware",
      "state": "OPEN",
      "isDraft": false,
      "reviewDecision": "APPROVED",
      "reviewRequests": []
    },
    "ci": {
      "state": "success",
      "checks": [
        { "name": "build", "status": "COMPLETED", "conclusion": "SUCCESS" },
        { "name": "test", "status": "COMPLETED", "conclusion": "SUCCESS" },
        { "name": "lint", "status": "COMPLETED", "conclusion": "SUCCESS" }
      ],
      "passing": 3,
      "failing": 0,
      "pending": 0,
      "total": 3
    },
    "push": { "ahead": 0, "behind": 0 }
  }
]
```

## Revision History

| Date | Author | Changes |
|----|----|----|
| 2026-02-13 | Nathan Heaps | Initial seed + first draft (Phase 1 & 2) |
| 2026-02-13 | Nathan Heaps | Research pass + refinement (Phase 3 & 4): clarified |
|    |    | standalone companion architecture, added data pipeline, |
|    |    | resolved open questions, added user stories, added |
|    |    | output mockups, refined technical considerations |
| 2026-02-13 | Nathan Heaps | Added Phase 1 MVP script requirements (FR-018 to FR-022), |
|    |    | CLI usage section, agent integration details, updated |
|    |    | architecture to Phase 1/Phase 2 approach, added JSON |
|    |    | output schema, moved from obsidian-vaults to git-spice |
|    |    | plugin docs |
