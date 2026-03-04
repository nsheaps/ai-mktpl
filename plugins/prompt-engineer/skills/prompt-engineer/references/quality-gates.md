# Quality Gates

Every generated prompt must embed these quality gates into the agent's workflow.
These are non-negotiable — the agent cannot skip any of them.

---

## 1. Per-Task Review Workflow

After EVERY task (not just at phase boundaries), the agent must run a multi-layer review.
This is embedded in the `/continue` command and the CLAUDE.md workflow section.

### Review Layers (in order)

```
Layer 1: Self-review
  Agent re-reads its own changes and checks for obvious issues.
  Quick sanity check before dispatching heavier reviews.

Layer 2: Project-specific reviewer sub-agent
  Dispatched on all changed files.
  Focuses on architecture compliance, project conventions, abstraction boundaries.
  Uses the project's specific review checklist (defined in .claude/agents/reviewer.md).

Layer 3: Plugin-based code review
  Use scm-utils from nsheaps/ai-mktpl for SCM-aware review patterns.
  Fallback: /pr-review-toolkit:review-pr (aspects: tests, errors, types, code, simplify)
  Fallback: /code-review (5 parallel agents)
  The agent should use whichever review plugins are installed,
  preferring nsheaps/ai-mktpl plugins.

Layer 4: Validation suite
  bun run validate (or equivalent) — lint, typecheck, unit, integration, E2E.
  ALL checks must pass.
```

### Review Loop

```
implement → self-review → reviewer agent → plugin review → validate
    ↑                                                          |
    └──── fix issues ←──── any failures? ←─────────────────────┘
```

The loop continues until:

- Reviewer agent returns APPROVE with zero 🔴 Critical issues
- Plugin review passes
- Full validation suite passes

### Embedding in the Generated Prompt

The `/continue` command template must include this exact workflow. Here's the pattern
to include in every generated prompt's `/continue` command:

```markdown
### Review (MANDATORY — never skip)

After implementation, run ALL of these reviews:

1. Self-review: re-read all changed files, check for obvious issues
2. Dispatch the **reviewer** sub-agent on all changed files
3. Run plugin-based review (prefer scm-utils, fallback to /pr-review-toolkit or /code-review)
4. Fix every 🔴 Critical issue. Address 🟡 Warnings. Consider 🔵 Suggestions.
5. Re-run reviews until the reviewer returns APPROVE with zero criticals.
6. Run full validation suite — must pass before committing.
```

---

## 2. Ralph Wiggum Quality Loop

The Ralph Wiggum loop is a self-referential iteration pattern where the agent repeatedly
examines its own work, finding and fixing issues until nothing remains.

### When to Use

- **End of every phase** (before `/phase-gate`) — MANDATORY
- **After major refactors** — recommended
- **When the user requests a quality sweep** — on demand

### How It Works

The agent uses the `/ralph-wiggum` plugin (from `anthropics/claude-code`). This plugin:

1. Examines all code produced in the current scope (phase, feature, etc.)
2. Identifies issues: missed edge cases, dead code, inconsistent patterns,
   missing tests, documentation gaps, code smells, accessibility issues
3. Fixes the issues it finds
4. Re-runs validation
5. Re-examines the code (including its own fixes)
6. Repeats until it finds nothing left to improve
7. Reports what it found and fixed

### Embedding in the Generated Prompt

Include this in the `/continue` command:

```markdown
## Ralph Wiggum Quality Loop

At the END of each phase (all tasks in a phase complete), use `/ralph-wiggum`:

- The loop iteratively re-examines all code produced in the phase
- It looks for: missed edge cases, dead code, inconsistent patterns, missing tests, doc gaps
- It fixes issues, re-validates, and repeats until clean
- Only after the Ralph loop completes cleanly should you run `/phase-gate`
```

Include this in the `/phase-gate` command:

```markdown
**Prerequisite:** The Ralph Wiggum loop (`/ralph-wiggum`) MUST have been run on the
phase's code and completed cleanly. If it hasn't, run it now before proceeding.
```

---

## 3. Phase Gates

Before starting a new phase, the agent runs `/phase-gate` which verifies:

1. All tasks in the current phase are marked complete in TASKS.md
2. Ralph Wiggum loop ran to completion with no remaining issues
3. Full validation suite passes
4. Plugin-based review of ALL files changed in the phase returns APPROVE
5. Code coverage meets target (configurable per project, default 80%)
6. Documentation is updated for all new features
7. E2E tests pass and screenshots are captured
8. A milestone commit is created and tagged
9. The tag is pushed

### Template for `/phase-gate`

```markdown
# /phase-gate — Phase Completion Verification

**Prerequisite:** `/ralph-wiggum` must have completed cleanly.

1. Verify all tasks in current phase are `[x]` in TASKS.md
2. Run full validation suite (`/validate`)
3. Dispatch **reviewer** sub-agent on ALL files changed in this phase
4. Run plugin-based review on the full phase diff
5. Fix any critical issues found, re-validate, re-review until clean
6. Check code coverage (target: [PROJECT_COVERAGE_TARGET]%)
7. Verify documentation updated for all new features
8. Run E2E tests, capture screenshots
9. Commit: `git commit -m "milestone: complete Phase X"`
10. Tag: `git tag phase-X-complete`
11. Push: `git push && git push --tags`

If any gate fails, list what's missing and do NOT proceed.
```

---

## 4. Sub-Agent Parallelism

The generated prompt must instruct the agent to dispatch sub-agents in parallel
whenever tasks are independent. This dramatically reduces wall-clock time.

### Parallel Patterns

```
Planning:
  code-explorer + code-architect → run simultaneously
  → merge findings → announce plan

Implementation:
  test-writer (writing failing tests) + implementer (independent module)
  → run simultaneously when modules don't depend on each other

Review:
  reviewer sub-agent + plugin review + doc-writer
  → can run simultaneously on the same diff

End of phase:
  Ralph Wiggum loop handles its own iteration
```

### Template for Sub-Agent Definitions

Every generated prompt should include at minimum these sub-agents:

**test-writer** — Writes comprehensive tests. Inputs: file/module path + source code.
Outputs: test files covering normal, edge, and error cases.

**reviewer** — Reviews code for project-specific concerns. Inputs: changed files or diff.
Outputs: issue list with severity and suggested fixes, ending with APPROVE or REQUEST CHANGES.

**doc-writer** — Writes documentation. Inputs: feature/module + source code.
Outputs: markdown docs with examples, prerequisites, troubleshooting.

Additional project-specific agents as needed (e.g., migrator, security-auditor, etc.).

### Embedding in the Generated Prompt

In the sub-agents section of the prompt:

```markdown
### Sub-Agents

**Parallelism principle:** Whenever tasks are independent (e.g., writing tests for
module A while implementing module B, or reviewing code while writing docs), dispatch
sub-agents in parallel. Don't serialize work that can be concurrent.

Combined with plugin-provided agents (from scm-utils, git-spice, and any review plugins),
the orchestrating agent has a large team of specialists. Use them aggressively.
```

---

## 5. Validation Suite

Every project needs a validation command that runs all quality checks. The generated
prompt must define this and wire it into the CI pipeline.

### Template for `/validate`

```markdown
# /validate — Full Quality Gate Check

Run the complete validation suite:

[PROJECT_VALIDATE_COMMAND]

Produce a summary table:

| Check             | Status | Details                       |
| ----------------- | ------ | ----------------------------- |
| Lint              | ✅/❌  | X warnings, Y errors          |
| Typecheck         | ✅/❌  | X errors                      |
| Unit Tests        | ✅/❌  | X passed, Y failed, Z skipped |
| Integration Tests | ✅/❌  | X passed, Y failed            |
| E2E Tests         | ✅/❌  | X passed, Y failed            |

If any check fails, list specific failures and propose fixes.
Do NOT proceed with new work until all checks pass.
```

---

## 6. Testing Requirements

Embed these in every generated prompt's CLAUDE.md and testing sections:

- Every new function/class gets unit tests
- Every new UI component gets component tests (if applicable)
- Every new user-visible feature gets E2E tests
- BDD feature files in `features/` for user-facing flows
- Validation suite must pass before committing
- Code coverage target: configurable, default 80%
- Screenshots captured for visual features
