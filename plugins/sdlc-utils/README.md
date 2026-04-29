# sdlc-utils

Software development lifecycle utilities -- one skill per SDLC phase.

## Skills

### plan

Planning and requirements. Guides iterative specification development through
research, review, and refinement cycles. Includes a spec template.

**Triggers:** "write a spec", "define requirements", "plan implementation", "break down a task"

### implement

Coding standards and implementation patterns. Covers code structure, naming
conventions, error handling, and following existing codebase patterns.

**Triggers:** "coding standards", "implementation patterns", "how to structure code"

### review

Code review practices and quality checks. Structured scoring across simplicity,
correctness, security, performance, maintainability, and more.

**Triggers:** "review code", "code review", "check code quality", "score this code"

### test

Testing strategy and validation. Covers test types, coverage expectations, and
validation workflows.

**Triggers:** "test strategy", "writing tests", "test coverage", "how to test this"

### deploy

Deployment and release management. Covers CI/CD configuration, release
strategies, and deployment validation.

**Triggers:** "deployment", "CI/CD", "release", "deploy pipeline"

### maintain

Maintenance, bug fixes, and technical debt management. Covers bug triage,
refactoring strategy, and dependency management.

**Triggers:** "bug fix", "tech debt", "refactoring", "maintenance"

### iterate-until-good

Evaluates code across many categories, scores each 0-100, and iterates until
all categories score > 85%. Uses scm-utils review skills for the review portion.

**Triggers:** "iterate until good", "score this code", "review and fix loop"

### spec-writing

Specification writing and lifecycle management. Covers creating specs, managing
the spec lifecycle (draft -> live -> archive), and using specs for verification.

**Triggers:** "write a spec", "manage spec lifecycle", "spec template", "update a spec"

### github-issues-task-management

Methodology for organizing work via GitHub Issues and Projects. Covers issue
lifecycle, PR-to-issue linking, label conventions, project board setup,
consolidation strategy, and cross-repo references. One concrete implementation
of the abstract work-tracking rules defined in `agentic-behavior`.

**Triggers:** "set up projects", "create a project board", "organize issues", "milestone planning", "consolidate tickets"

## Dependencies

- **scm-utils** — the `iterate-until-good` and `review` skills delegate to scm-utils
  review skills for code scoring. Install both plugins from the same marketplace.

## Installation

Install via the nsheaps-claude-plugins marketplace:

```
sdlc-utils@nsheaps-claude-plugins
scm-utils@nsheaps-claude-plugins
```
