---
name: rest-owl
description: >
  Turn a simple idea into a fully-specified, tested, and validated software project.
  Activates when a user describes a project idea in brief (e.g., "build a Notion clone",
  "make a Slack competitor", "create a task management app"). Orchestrates research,
  specification, design, implementation, and validation into a complete deliverable.
argument-hint: "<project idea in plain English>"
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, Agent, WebSearch, WebFetch, TodoWrite, AskUserQuestion, NotebookEdit
---

# Rest of the Owl

> "How to draw an owl: Step 1 — Draw two circles. Step 2 — Draw the rest of the fucking owl."

This skill turns a napkin-sketch idea into a production-ready software project. The user provides a simple concept; you deliver a fully researched, specified, designed, tested, and validated codebase.

This is **agentic engineering** — not vibe coding. You are orchestrating structured work with human oversight at every stage. The planning phases (0-5) are where the engineering expertise matters most; the build phase (6) follows naturally from thorough upfront work. Better specs produce better code. Comprehensive tests enable confident delegation. Clean architecture reduces hallucination.

## Philosophy

The user's job is to have the idea. Your job is everything else:

- **Research** what already exists and what users expect
- **Specify** every feature in detail with acceptance criteria — specs are executable prompts, not documentation
- **Design** the visual interface with concrete mockups
- **Architect** the technical solution with clear decisions and a project constitution
- **Plan** the implementation in buildable milestones
- **Build** test-first: write tests from specs, then implement until they pass
- **Validate** with automated visual regression and E2E tests in CI
- **Hand off** with clear documentation so the user can own and maintain the code

## Activation

This skill activates when a user provides a brief project description. Examples:

- "Build a Notion clone"
- "I want a Slack competitor"
- "Create a personal finance tracker"
- "Make a recipe sharing app"
- "Build me a project management tool like Linear"

## Orchestration Phases

The rest-owl workflow has 7 phases. Each phase produces artifacts that feed the next. **Never skip phases** — the quality of the final product depends on thorough upfront work.

### Phase 0: Intake & Clarification

**Goal**: Understand the user's vision well enough to research effectively.

1. Acknowledge the idea and summarize your understanding back to the user
2. Ask targeted clarifying questions using `AskUserQuestion`:
   - **Target users**: Who is this for? (developers, consumers, enterprise, internal)
   - **Platform**: Web app, mobile, desktop, CLI, API?
   - **Scale**: MVP/prototype, production-ready, or enterprise-grade?
   - **Tech preferences**: Any framework/language preferences or constraints?
   - **Key differentiator**: What should make this stand out from existing solutions?
   - **Timeline scope**: Full product or focused MVP subset?
3. Draft a **positioning statement** (2-3 sentences): what this project is, who it's for, and how it differs from existing solutions. This bridges research and specification.
4. Save the intake summary to `docs/rest-owl/00-intake.md`

**Output**: `docs/rest-owl/00-intake.md` — project brief with user's answers and positioning statement

### Phase 1: Competitive Research

**Goal**: Understand the landscape of existing solutions and user expectations.

**Invoke the `competitive-research` skill** with the project brief.

This phase produces:

- Analysis of 5-10 existing products in the space
- Feature matrix comparing competitors
- Common UX patterns and user expectations
- Identified gaps and opportunities
- Technology choices made by competitors

**Output**: `docs/rest-owl/01-competitive-research.md`

### Phase 2: Feature Specification

**Goal**: Define every feature the project needs, with acceptance criteria.

**Invoke the `feature-spec` skill** with the competitive research output.

This phase produces:

- Complete feature inventory organized by domain
- Each feature has: description, user stories, acceptance criteria, priority (P0-P3)
- Data model definitions
- API endpoint specifications (if applicable)
- State management requirements
- Edge cases and error scenarios

**Output**: `docs/rest-owl/02-feature-spec.md`

### Phase 3: Visual Design & Mockups

**Goal**: Create concrete visual representations of every screen and interaction.

**Invoke the `visual-design` skill** with the feature spec.

This phase produces:

- Design system (colors, typography, spacing, components)
- ASCII/text wireframes for every screen
- Single-file HTML mockups for key screens (renderable in browser)
- Responsive layout specifications
- Interaction flow diagrams
- Accessibility requirements

**Output**:

- `docs/rest-owl/03-design-system.md`
- `docs/rest-owl/03-mockups/` — directory of HTML mockup files
- `docs/rest-owl/03-wireframes.md` — ASCII wireframes

### Phase 4: Technical Architecture

**Goal**: Make all technical decisions and document the system design.

1. **Technology stack selection** — framework, database, auth, hosting, based on:
   - User's stated preferences from Phase 0
   - Competitive research findings from Phase 1
   - Feature requirements from Phase 2
   - Visual complexity from Phase 3

2. **System architecture**:
   - Component hierarchy / module structure
   - Data flow diagrams
   - Database schema (ERD in text form)
   - API design (REST/GraphQL/tRPC)
   - Authentication and authorization model
   - Third-party service integrations

3. **Project scaffolding decisions**:
   - Directory structure
   - Build tooling and configuration
   - Development workflow (dev server, hot reload, etc.)
   - Dependency list with justifications

4. **Project constitution** — a `CLAUDE.md` (or equivalent rules file) that establishes non-negotiable project rules for all subsequent AI-generated code:
   - Architecture patterns and constraints
   - Coding standards and conventions
   - Security requirements
   - Testing requirements (coverage targets, test patterns)
   - Naming conventions
   - Import/dependency rules

   This file is placed in the project root and ensures consistent code generation across all milestones. Inspired by GitHub's Spec Kit `/speckit.constitution` pattern.

**Output**:
- `docs/rest-owl/04-architecture.md` — technical decisions and system design
- `CLAUDE.md` (project root) — constitution / project rules for AI code generation

### Phase 5: Implementation Plan

**Goal**: Break the build into ordered milestones with clear deliverables.

1. **Milestone breakdown**:
   - Each milestone is independently deployable
   - Milestones ordered by dependency (foundation first)
   - Each milestone lists: features included, files to create/modify, tests required
   - Estimated complexity per milestone (S/M/L/XL)

2. **Testing strategy per milestone**:
   - Unit tests for business logic
   - Integration tests for API endpoints
   - Component tests for UI elements
   - E2E tests for critical user flows
   - Visual regression tests for key screens

3. **CI/CD pipeline design**:
   - Build and lint checks
   - Unit and integration test jobs
   - E2E test jobs with screenshot capture
   - Visual regression comparison against baseline screenshots
   - Deploy preview for PRs

**Output**: `docs/rest-owl/05-implementation-plan.md`

### Phase 6: Build & Validate

**Goal**: Implement the project milestone by milestone with full test coverage.

**Test-first approach**: Write tests derived from Phase 2 acceptance criteria BEFORE writing implementation code. Then implement until all tests pass. This is what makes agentic engineering reliable — with a solid test suite, the AI can iterate in a loop until tests pass, giving high confidence in the result.

For each milestone:

1. **Scaffold** — Create files, install dependencies, configure tooling
2. **Write tests first** — Translate acceptance criteria from Phase 2 into unit tests, component tests, and E2E tests. These tests will initially fail.
3. **Implement** — Build features until all tests pass
4. **Visual baseline** — Capture screenshot baselines for visual regression
5. **CI integration** — Ensure all tests run in CI with screenshot artifacts

**Invoke the `validation-pipeline` skill** to set up the testing infrastructure.

After each milestone:

- Run all tests locally — all must pass
- Verify visual baselines match mockups from Phase 3
- Commit with conventional commit messages
- Update implementation plan with completion status

**Output**: The actual codebase with full test coverage

### Phase 7: Handoff & Ownership

**Goal**: Ensure the user understands and can maintain the generated codebase.

This phase addresses a critical reality: agentic engineering produces code quickly, but the user must own and maintain it. Without understanding the architecture and key decisions, the codebase becomes unmaintainable.

1. **Architecture walkthrough** — Summarize the key architectural decisions and why they were made. Reference specific files and patterns.

2. **Code tour** — Identify the 5-10 most important files/modules and explain what each does and how they connect.

3. **Extension guide** — Document how to add common things:
   - A new feature (which files to create, what patterns to follow)
   - A new API endpoint
   - A new UI screen
   - A new test

4. **Known limitations** — Be honest about what was deferred, simplified, or left as a TODO. List areas that will need attention as the project scales.

5. **Maintenance checklist** — What the user should do regularly:
   - Dependency updates
   - Visual baseline updates after intentional UI changes
   - Test coverage monitoring

**Output**: `docs/rest-owl/06-handoff.md` — architecture guide and maintenance instructions

## Artifact Directory Structure

All rest-owl artifacts live under `docs/rest-owl/` in the project root:

```
docs/rest-owl/
├── 00-intake.md                    # Project brief, user answers, positioning statement
├── 01-competitive-research.md      # Market analysis and feature matrix
├── 02-feature-spec.md              # Complete feature specifications
├── 03-design-system.md             # Colors, typography, components
├── 03-mockups/                     # HTML mockup files
│   ├── dashboard.html
│   ├── login.html
│   ├── settings.html
│   └── ...
├── 03-wireframes.md                # ASCII wireframes for all screens
├── 04-architecture.md              # Technical decisions and system design
├── 05-implementation-plan.md       # Milestones, tasks, and testing strategy
└── 06-handoff.md                   # Architecture guide and maintenance instructions
```

Additionally, a `CLAUDE.md` constitution file is created in the project root during Phase 4.

## User Checkpoints

**Never proceed to the next phase without user approval.** After each phase:

1. Present a summary of what was produced
2. Highlight key decisions that were made
3. Ask: "Does this look right? Anything you'd change before we move on?"
4. Incorporate feedback before proceeding

This ensures the user stays in control while you handle the complexity.

## Parallel Execution Strategy

Where possible, use the `Agent` tool to parallelize independent work:

- **Phase 1**: Launch multiple research agents for different competitors simultaneously
- **Phase 3**: Generate mockups for independent screens in parallel
- **Phase 6**: Run tests for independent modules in parallel

Use `TodoWrite` throughout to track progress across all phases.

## Resumption

If a session ends mid-workflow, the artifact files serve as checkpoints. On resumption:

1. Check `docs/rest-owl/` for existing artifacts
2. Determine which phase was last completed
3. Resume from the next incomplete phase
4. Show the user a status summary of where things stand

## Anti-Patterns

- **Never skip research** — even if you "know" the domain, research validates assumptions
- **Never generate code before spec** — the spec is the contract; code without spec is guessing
- **Never skip mockups** — visual design catches UX issues before they become code bugs
- **Never ship without visual regression** — screenshots in CI catch visual regressions automatically
- **Never batch all testing to the end** — test each milestone as you build it
- **Never make tech decisions without justification** — every choice in the architecture doc needs a "why"
- **Never skip the handoff** — generating code the user can't maintain creates dangerous skill atrophy
- **Never treat this as vibe coding** — every phase exists for a reason; accepting AI output without review is not agentic engineering
