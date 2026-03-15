# rest-owl

> "How to draw an owl: Step 1 — Draw two circles. Step 2 — Draw the rest of the fucking owl."

Turn a simple idea into a fully researched, specified, designed, tested, and validated software project.

## What It Does

You say "build a Notion clone." This plugin handles everything else:

1. **Competitive Research** — Analyzes 5-10 existing products, builds feature matrices, identifies patterns
2. **Feature Specification** — Writes detailed specs with user stories, acceptance criteria, data models, API definitions
3. **Visual Design** — Creates a design system, ASCII wireframes, and renderable HTML mockups for every screen
4. **Technical Architecture** — Makes and documents all tech stack decisions with justifications
5. **Implementation Planning** — Breaks the build into ordered milestones with testing requirements
6. **Build & Validate** — Implements with unit tests, E2E tests, and visual regression testing in CI

## Usage

### Slash Command

```
/rest-owl build a project management tool like Linear
```

### Direct Prompt

Just describe your idea in conversation. The `rest-owl` skill activates when it detects a brief project description.

## Skills

| Skill                  | Purpose                                              |
| ---------------------- | ---------------------------------------------------- |
| `rest-owl`             | Main orchestrator — coordinates all phases           |
| `competitive-research` | Phase 1: Market analysis and feature comparison      |
| `feature-spec`         | Phase 2: Detailed feature specifications             |
| `visual-design`        | Phase 3: Design system, wireframes, and HTML mockups |
| `validation-pipeline`  | Phase 6: Testing infrastructure and CI setup         |

## Artifacts

All design artifacts are saved to `docs/rest-owl/` in the project:

```
docs/rest-owl/
├── 00-intake.md                    # Project brief
├── 01-competitive-research.md      # Market analysis
├── 02-feature-spec.md              # Feature specifications
├── 03-design-system.md             # Design tokens
├── 03-wireframes.md                # ASCII wireframes
├── 03-mockups/                     # HTML mockup files
├── 04-architecture.md              # Technical architecture
└── 05-implementation-plan.md       # Build milestones
```

These artifacts serve as:

- **Session checkpoints** — resume work across sessions
- **Design documentation** — stakeholders can review mockups in any browser
- **Visual baselines** — CI screenshots compare against mockups

## Visual Regression Testing

The validation-pipeline skill sets up Playwright-based visual regression:

- Screenshots HTML mockups at standard viewports (desktop/tablet/mobile)
- Compares implemented UI against mockup baselines in CI
- Uploads diff artifacts on failure
- Comments on PRs when visual regressions are detected

## User Checkpoints

The workflow pauses after each phase for user review. No phase proceeds without explicit approval, ensuring the user stays in control while the agent handles complexity.

## Configuration

Settings in `rest-owl.settings.yaml` or override in `.claude/plugins.settings.yaml`:

| Key                   | Default                     | Description                              |
| --------------------- | --------------------------- | ---------------------------------------- |
| `enabled`             | `true`                      | Enable/disable plugin                    |
| `artifactsDir`        | `docs/rest-owl`             | Where to save design artifacts           |
| `minCompetitors`      | `5`                         | Minimum competitors to research          |
| `generateHtmlMockups` | `true`                      | Create HTML mockups (vs wireframes only) |
| `screenshotViewports` | `[desktop, tablet, mobile]` | Viewports for visual regression          |
| `visualDiffThreshold` | `0.01`                      | Pixel diff threshold (0.0-1.0)           |
| `setupCi`             | `true`                      | Auto-create CI workflow                  |
| `testRunner`          | `vitest`                    | Unit test runner                         |
| `e2eFramework`        | `playwright`                | E2E test framework                       |

## Session Hook

A SessionStart hook detects existing `docs/rest-owl/` artifacts and reports which phases are complete, making it easy to resume interrupted workflows.
