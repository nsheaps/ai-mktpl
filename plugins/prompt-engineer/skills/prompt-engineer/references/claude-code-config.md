# Claude Code Configuration Templates

Templates for the Claude Code integration section of generated prompts.
Adapt these to each project's needs.

---

## .claude/settings.json Template

```json
{
  "permissions": {
    "allow": [
      "bash(mise *)",
      "bash(bun *)",
      "bash(bunx *)",
      "bash(npx *)",
      "bash(nx *)",
      "bash(git *)",
      "bash(gs *)",
      "bash(node *)",
      "bash(cat *)",
      "bash(ls *)",
      "bash(find *)",
      "bash(grep *)",
      "bash(head *)",
      "bash(tail *)",
      "bash(wc *)",
      "bash(sort *)",
      "bash(mkdir *)",
      "bash(cp *)",
      "bash(mv *)",
      "bash(rm *)",
      "bash(chmod *)",
      "bash(sed *)",
      "bash(awk *)",
      "bash(curl *)",
      "bash(which *)",
      "bash(echo *)",
      "bash(printf *)",
      "bash(test *)",
      "bash(diff *)",
      "bash(patch *)",
      "bash(xargs *)",
      "bash(tee *)"
    ],
    "deny": []
  },
  "env": {
    "FORCE_COLOR": "1",
    "NODE_ENV": "development"
  },
  "extraKnownMarketplaces": {
    "nsheaps-ai-mktpl": {
      "source": {
        "source": "github",
        "repo": "nsheaps/ai-mktpl"
      }
    },
    "claude-plugins-official": {
      "source": {
        "source": "github",
        "repo": "anthropics/claude-plugins-official"
      }
    },
    "anthropics-claude-code": {
      "source": {
        "source": "github",
        "repo": "anthropics/claude-code"
      }
    }
  },
  "enabledPlugins": {
    "scm-utils@nsheaps-ai-mktpl": true,
    "git-spice@nsheaps-ai-mktpl": true,
    "ralph-loop@anthropics-claude-code": true
  }
}
```

**Customization points:**

- Add project-specific `bash()` permissions (e.g., `bash(docker *)`, `bash(cargo *)`)
- Add project-specific `env` vars
- Add project-specific `enabledPlugins` (discovered during Phase -1)
- The three marketplaces and two nsheaps plugins are ALWAYS present

---

## Session-Start Script Template

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== [PROJECT_NAME] Session Bootstrap ==="

# ---- 1. Detect environment ----
IS_EPHEMERAL=false
if [[ -f /.dockerenv ]] || [[ "${CODESPACES:-}" == "true" ]] || [[ -n "${CLAUDE_CODE_WEB:-}" ]]; then
  IS_EPHEMERAL=true
  echo "[env] Ephemeral container detected"
fi

# ---- 2. Install mise (if needed) ----
if ! command -v mise &>/dev/null; then
  echo "[mise] Installing..."
  curl https://mise.run | sh
  export PATH="$HOME/.local/bin:$PATH"
fi
echo "[mise] $(mise --version)"

# ---- 3. Install tools via mise ----
mise install --yes
echo "[tools] All tools installed"

# ---- 4. Install dependencies ----
[PACKAGE_INSTALL_COMMAND]
echo "[deps] Dependencies installed"

# ---- 5. Install git-spice ----
if ! command -v gs &>/dev/null; then
  echo "[git-spice] Installing..."
  go install go.abhg.dev/git-spice@latest 2>/dev/null || \
    brew install git-spice 2>/dev/null || \
    echo "[git-spice] Manual install needed: https://abhinav.github.io/git-spice/"
fi
if command -v gs &>/dev/null; then
  gs repo init 2>/dev/null || true
  echo "[git-spice] $(gs --version 2>/dev/null || echo 'ready')"
fi

# ---- 6. Plugin installation ----
echo "[plugins] Installing plugins from marketplaces..."
if command -v claude &>/dev/null; then
  # Priority 1: nsheaps/ai-mktpl
  claude plugin marketplace add nsheaps/ai-mktpl 2>/dev/null || true
  claude plugin install scm-utils@nsheaps-ai-mktpl 2>/dev/null || true
  claude plugin install git-spice@nsheaps-ai-mktpl 2>/dev/null || true
  [ADDITIONAL_NSHEAPS_PLUGINS]

  # Priority 2: anthropics/claude-plugins-official
  claude plugin marketplace add anthropics/claude-plugins-official 2>/dev/null || true
  [ADDITIONAL_OFFICIAL_PLUGINS]

  # Priority 3: anthropics/claude-code
  claude plugin marketplace add anthropics/claude-code 2>/dev/null || true
  claude plugin install ralph-loop@anthropics-claude-code 2>/dev/null || true
  [ADDITIONAL_BUNDLED_PLUGINS]

  echo "[plugins] Installation complete"
else
  echo "[plugins] Claude CLI unavailable — plugins install on first interactive session"
fi

# ---- 7. Branch management ----
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")

# Sync with remote
git fetch origin 2>/dev/null || true

# If on a WIP branch, handle it
if [[ "$CURRENT_BRANCH" == wip/* ]]; then
  echo "[branch] WIP branch detected: $CURRENT_BRANCH"
  echo "[branch] Rebasing onto main..."
  git checkout main
  git pull origin main --rebase
  git rebase main "$CURRENT_BRANCH"
  git checkout main
  git merge --ff-only "$CURRENT_BRANCH"
  git branch -d "$CURRENT_BRANCH"
  git push
  echo "[branch] WIP branch merged and cleaned up"
elif [[ "$CURRENT_BRANCH" != "main" ]]; then
  # Not on main and not a WIP — might be a stacked branch
  if command -v gs &>/dev/null; then
    gs repo sync 2>/dev/null || true
    gs repo restack 2>/dev/null || true
  fi
fi

# ---- 8. Quick validation ----
echo "[validate] Running quick checks..."
[VALIDATE_COMMAND] || echo "[validate] Some checks failed — will fix during task execution"

# ---- 9. Status ----
echo ""
echo "=== Session Ready ==="
if [[ -f "TASKS.md" ]]; then
  echo "--- Current Progress ---"
  grep -n "^\- \[x\]" TASKS.md | tail -3 || true
  echo "..."
  grep -n "^\- \[ \]" TASKS.md | head -3 || true
fi
if command -v gs &>/dev/null; then
  echo "--- Stack ---"
  gs log short 2>/dev/null || true
fi
echo "========================"
```

**Customization points marked with [BRACKETS]:**

- `[PROJECT_NAME]` — project name
- `[PACKAGE_INSTALL_COMMAND]` — e.g., `bun install`, `npm ci`, `cargo build`
- `[ADDITIONAL_*_PLUGINS]` — project-specific plugins
- `[VALIDATE_COMMAND]` — e.g., `bun run validate`, `npm test`, `cargo check`

---

## Slash Command Templates

### /continue (CRITICAL — this is the main development driver)

```markdown
# /continue — Resume Development

Read TASKS.md and determine current phase and next incomplete task.

## Pre-flight

1. Ensure git-spice stack is synced: `gs repo sync && gs repo restack`
2. Run validation. Fix failures before starting new work.

## Task Execution Loop (per task)

### 1. Plan (use sub-agents in parallel)

- Dispatch sub-agents to analyze files and design approach (in parallel)
- Write/update the BDD feature file for this task
- Create stacked branch: `gs branch create T<X>.<Y>-<description>`

### 2. Implement (parallelize independent work)

- Write failing tests first (Red)
- Implement minimum code to pass (Green)
- Refactor while keeping tests green
- Make atomic commits for each logical sub-step

### 3. Review (MANDATORY — never skip)

- Dispatch **reviewer** sub-agent on changed files
- Run plugin-based review (prefer scm-utils from nsheaps/ai-mktpl, fallback to other review plugins)
- Fix all 🔴 Critical issues. Re-review until APPROVE with zero criticals.

### 4. Validate

- Full validation suite must pass
- BDD scenarios for this feature must pass

### 5. Submit

- `gs branch submit --fill` to create/update PR
- If next task depends on this: create stacked branch on top
- If next task is independent: create branch from appropriate base

### 6. Continue or Report

- If context/time remaining: next task, repeat from step 1
- If running low: print summary

## Ralph Wiggum Quality Loop

At END of each phase, run `/ralph-loop` for iterative quality sweep.
Only after clean completion, run `/phase-gate`.
```

### /validate

```markdown
# /validate — Full Quality Gate Check

Run the complete validation suite and report results as a table.
If any check fails, list specific failures and propose fixes.
Do NOT proceed with new feature work until all checks pass.
```

### /status

```markdown
# /status — Project Status Report

1. Read TASKS.md — count completed vs total per phase
2. Show recent commits: `git log --oneline -10`
3. Show stack: `gs log short`
4. Run quick validation
5. Check for TODO/FIXME/HACK comments
6. Print formatted summary with progress bars per phase
```

### /phase-gate

```markdown
# /phase-gate — Phase Completion Verification

Prerequisite: `/ralph-loop` must have completed cleanly.

1. All tasks in phase marked [x] in TASKS.md
2. Ralph Wiggum loop verified clean
3. Full validation passes
4. Reviewer sub-agent approves full phase diff
5. Plugin-based review approves
6. Code coverage meets target
7. Documentation updated
8. E2E tests pass with screenshots
9. Milestone commit + tag + push
```

---

## Sub-Agent Templates

### .claude/agents/test-writer.md

```markdown
# Test Writer Agent

You write comprehensive tests for [PROJECT_NAME].

## Inputs

- File path or module name to test
- Source code of that module
- Testing framework: [TEST_FRAMEWORK]

## Outputs

- Complete test files: normal cases, edge cases, error cases
- BDD step definitions where applicable

## Rules

- Descriptive test names
- Group in describe blocks
- Use fixtures when available
- Mock external deps in unit tests, real instances in E2E
- Target: every branch covered by at least one test
```

### .claude/agents/reviewer.md

```markdown
# Code Reviewer Agent

You review code for [PROJECT_NAME]-specific concerns that generic reviewers miss.

## Inputs

- Changed files or diff

## Checklist

1. Architecture compliance — abstraction boundaries respected?
2. TypeScript/language quality — no escape hatches?
3. Error handling — graceful, user-friendly?
4. Testing — corresponding tests exist? Edge cases?
5. Performance — N+1 loops? Unnecessary re-renders?
6. Accessibility — keyboard nav? ARIA? Semantic HTML?
7. Project conventions — commit format? File organization?
8. Documentation — JSDoc on public APIs?
9. Security — no secrets? Input sanitized?

## Output

Per issue: File:line, Severity (🔴/🟡/🔵), Issue, Fix
Summary: "X critical, Y warnings, Z suggestions. [APPROVE/REQUEST CHANGES]"
```

### .claude/agents/doc-writer.md

```markdown
# Documentation Writer Agent

You write clear documentation for [PROJECT_NAME].

## Inputs

- Feature or module + source code

## Outputs

- Markdown docs with examples, prerequisites, troubleshooting
- API reference for developer-facing modules
- User guides for end-user features

## Rules

- Every guide: "What you'll learn" + "Prerequisites"
- Short paragraphs (3-4 sentences)
- Cross-link related docs
- Include troubleshooting section
```

---

## CLAUDE.md Template

```markdown
# [PROJECT_NAME]

[One paragraph project description]

## Architecture

[Key architecture rules the agent must follow]

## Key Commands

| Command            | What it does                            |
| ------------------ | --------------------------------------- |
| [DEV_COMMAND]      | Start dev server / watch mode           |
| [VALIDATE_COMMAND] | Full lint + typecheck + test            |
| [TEST_COMMAND]     | Run all tests                           |
| `gs log short`     | View git-spice branch stack             |
| `gs repo sync`     | Sync with remote, clean merged branches |

## Installed Plugins & Workflow

Plugins installed from three marketplaces (nsheaps/ai-mktpl priority):

- `scm-utils` (nsheaps/ai-mktpl) — SCM patterns, code review
- `git-spice` (nsheaps/ai-mktpl) — stacked branch management
- `ralph-loop` (anthropics/claude-code) — iterative quality loops
  [Additional project-specific plugins]

**Per-task workflow:**

1. Create stacked branch: `gs branch create T<X>.<Y>-<desc>`
2. Implement with atomic commits
3. Review: reviewer sub-agent → plugin review → validate
4. Fix criticals, re-review until APPROVE
5. Submit: `gs branch submit --fill`

**Per-phase workflow:**

1. Complete all tasks
2. `/ralph-loop` for quality sweep
3. `/phase-gate` for formal verification

## Task Tracking

Current progress in TASKS.md. Follow task execution protocol.
Never skip reviews. Never skip Ralph Wiggum loop at phase end.

## Session Resume

1. `gs repo sync && gs repo restack` (sync stack with remote)
2. Read TASKS.md for current progress
3. Validate repo health
4. Continue from next incomplete task
```
