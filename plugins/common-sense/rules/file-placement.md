# File Placement Rules

When saving files (research, plans, notes, specifications, outputs), place them according to their permanence and purpose.

## Decision Framework

**Core Test**: _If you restarted your session and this file was deleted, would the work have been for nothing?_

- **YES** → File belongs in a **permanent location** (docs/, .claude/plans/, .claude/scratch/)
- **NO** → File is **temporary** and can go to `.claude/tmp/`

## Directory Purposes

### `.claude/tmp/` — Truly Temporary, Disposable

Files placed here are **expected to be discarded** and should never represent completed work.

**Use for:**

- Intermediate build outputs or compiler cache
- One-time command output captures (git logs, test runs)
- Running session logs (like `ai-agent-eng-failure-log.md`)
- Debugging artifacts that have no lasting value
- Scratch calculations or exploratory work that will be summarized elsewhere

**NEVER use for:**

- Completed research (use `docs/research/`)
- Implementation plans (use `.claude/plans/`)
- Specifications (use `docs/specs/`)
- Summary notes of value (use `.claude/scratch/`)
- Any artifact that took significant effort to produce

### `docs/research/` — Research Findings (Permanent)

Research outputs that provide context, patterns, or findings for future work.

**Use for:**

- Investigation reports (e.g., "How teammate launching works")
- Technology evaluations (comparing libraries, frameworks, approaches)
- Architecture exploration results
- API/system analysis reports
- Literature reviews or reference compilations
- Any findings that inform future development

**Examples:**

- `docs/research/agent-launch-behavior.md` — How Claude Code spawns agents
- `docs/research/tmux-integration-deep-dive.md` — Findings on tmux integration
- `docs/research/mcp-feasibility-assessment.md` — MCP server viability study

### `docs/specs/` — Specifications (Permanent)

Product and technical specifications that guide development.

**Structure:**

```
docs/specs/
├── draft/           # Initial drafts and brainstorming
├── reviewed/        # Reviewed and approved specs
├── in-progress/     # Specs currently being implemented
├── live/            # Finalized specs in active use
├── deprecated/      # Outdated but still referenced
└── archive/         # No longer in use
```

**Use for:**

- Feature specifications
- API specifications
- Architecture design documents
- Technical requirements
- Use cases and user stories
- Any formal spec that guides implementation

**Examples:**

- `docs/specs/draft/agent-orchestration-v2.md` — Emerging orchestration design
- `docs/specs/live/cli-commands.md` — Formal spec of CLI interface

### `.claude/plans/` — Implementation Plans (Permanent)

Step-by-step plans for implementing tasks or features.

**Use for:**

- Multi-phase implementation plans
- Architectural decision documents with rationale
- Task decomposition and sequencing
- Known risks and mitigation strategies
- Testing and validation plans
- Any plan that accompanies a significant task

**Examples:**

- `.claude/plans/3-script-architecture-refactor.md` — Breaking down the 3-script split
- `.claude/plans/teammate-health-check-system.md` — Design for agent health monitoring

### `.claude/scratch/` — Working Notes (Semi-Permanent)

Notes that may eventually become permanent documents, or working areas for ongoing tasks.

**Use for:**

- Meeting notes or discussion summaries
- Task lists and progress tracking (`.claude/scratch/tasks.md`)
- Brain dumps that might become specs
- Session notes that capture thinking
- Working state that will be cleaned up or formalized later

**Examples:**

- `.claude/scratch/tasks.md` — Current task list
- `.claude/scratch/session-notes.md` — Notes from this session
- `.claude/scratch/refactor-thoughts.md` — Preliminary ideas before formalizing

## Examples: Where Things Belong

| Artifact                                              | Belongs In                          | Why                                   |
| ----------------------------------------------------- | ----------------------------------- | ------------------------------------- |
| "I researched how teammate spawning works" (findings) | `docs/research/teammate-launch.md`  | Worth preserving for future reference |
| Intermediate curl output from API exploration         | `.claude/tmp/api-response.json`     | Used once, discarded after extraction |
| Implementation plan for the refactor                  | `.claude/plans/refactor-plan.md`    | Guides work across sessions           |
| Running failure log entries                           | `.claude/tmp/failure-log.md`        | Session-scoped audit trail            |
| Draft feature spec being iterated                     | `docs/specs/draft/feature-name.md`  | Formalizing a spec                    |
| Notes from research session                           | `.claude/scratch/research-notes.md` | May become permanent, kept accessible |
| Test output from a single run                         | `.claude/tmp/test-output.txt`       | Debugging artifact, not needed later  |
| Formal API specification                              | `docs/specs/live/api.md`            | Reference document, permanent         |
| Exploratory code snippets                             | `.claude/tmp/code-exploration.md`   | Throwaway work                        |
| Summary of findings to guide future work              | `docs/research/findings.md`         | Value accrues over time               |

## Rules for Agents

1. **Before saving, ask**: "Would this file be useful after a session restart?"
   - **Yes** → Use permanent location
   - **No** → Can use `.claude/tmp/`

2. **Completed work never goes to tmp**: Research finished, specs drafted, plans written, or reports completed should always go to permanent locations.

3. **Default to permanent**: When uncertain, prefer permanent locations. It's easy to move something later, but harder to recover if it's deleted.

4. **Summarize tmp outputs**: If you created intermediate files in tmp, summarize the findings in a permanent location (research, plans, or scratch).

5. **Clean up thoughtfully**: Don't use "clean tmp" as an excuse to delete work you haven't summarized or preserved elsewhere.

## Connection to Project Standards

This rule aligns with:

- **Spec-driven development** (`mantras-and-incremental-development.md`): Specs live in `docs/specs/`, not tmp
- **Artifact linking in reports** (`artifact-linking-in-reports.md`): Links should point to permanent locations
- **Research integrity**: Findings must be preserved for future reference
- **STEM mindset**: Document and retain what you learn

## Anti-Patterns to Avoid

| Bad                                 | Why                                       | Good                              |
| ----------------------------------- | ----------------------------------------- | --------------------------------- |
| "I'll save research to tmp for now" | Tmp gets cleaned, research lost           | Save to `docs/research/` directly |
| "This is temporary planning"        | Plans aren't temporary if they guide work | Save to `.claude/plans/`          |
| "I'll move it later"                | Later rarely happens, work gets forgotten | Place correctly the first time    |
| Dumping everything to tmp           | Defeats the purpose of permanent storage  | Categorize and place with intent  |

## Questions?

If you're unsure where something belongs, ask the permanence test:

> "If this session ends and I lose this file, is the work wasted?"

**Yes** → permanent location
**No** → can use tmp

---

_See Failure #17 in `.claude/tmp/ai-agent-eng-failure-log.md` for the pattern analysis and discovery of this issue._
