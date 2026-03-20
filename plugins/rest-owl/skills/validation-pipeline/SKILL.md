---
name: validation-pipeline
description: >
  Set up comprehensive testing and CI validation infrastructure for a software project.
  Includes unit tests, E2E tests with Playwright, visual regression testing with screenshot
  comparison, and GitHub Actions CI pipeline with screenshot artifact capture.
  Used as Phase 6 of the rest-owl workflow.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent, WebSearch, WebFetch, TodoWrite, AskUserQuestion
---

# Validation Pipeline

Sets up a complete testing and continuous integration infrastructure that validates code correctness, user flows, and visual accuracy — including screenshot-based visual regression testing in CI.

## When This Skill Activates

- As Phase 6 of the rest-owl workflow
- When a user needs to set up a testing infrastructure for a new project
- When adding visual regression testing to an existing project
- When configuring CI for a project with E2E and screenshot tests

## Input

- Implementation plan (`docs/rest-owl/05-implementation-plan.md`)
- HTML mockups (`docs/rest-owl/03-mockups/`) — visual baselines
- Design system (`docs/rest-owl/03-design-system.md`)
- Feature spec (`docs/rest-owl/02-feature-spec.md`) — acceptance criteria become tests

## Tool Selection

The examples below default to **Bun** as the runtime and **Playwright** for E2E testing. These are defaults — adapt to whatever the user chose in Phase 0 and Phase 4 (architecture). The `testRunner` and `e2eFramework` settings in `rest-owl.settings.yaml` also control defaults. The patterns and principles apply regardless of specific tool choices.

## Testing Layers

### Layer 1: Unit Tests

Test individual functions, utilities, and business logic in isolation.

**Setup**:

- Use the project's native test runner (Vitest for Vite/React, Jest for Next.js, Bun test for Bun)
- Co-locate tests next to source files: `component.test.ts` alongside `component.ts`
- Mock external dependencies (APIs, databases, third-party services)

**What to test**:

- Pure functions and utilities
- Data transformations and validation
- State management logic (reducers, stores)
- Custom hooks (if React/Vue)
- API route handlers (request → response)

**Coverage targets**:

- Business logic: 90%+
- Utilities: 95%+
- Overall: 80%+

### Layer 2: Component Tests

Test UI components in isolation with realistic props and interactions.

**Setup**:

- Use Testing Library (`@testing-library/react`, `@testing-library/vue`, etc.)
- Render components with mock data matching feature spec
- Test user interactions (click, type, submit)
- Verify accessibility (role queries, aria attributes)

**What to test**:

- Component renders correctly with various props
- User interactions trigger expected behavior
- Loading, empty, and error states render correctly
- Form validation works as specified
- Responsive behavior (media query changes)

### Layer 3: E2E Tests (Playwright)

Test complete user flows through the real application.

**Setup**:

```bash
# Install Playwright
bun add -d @playwright/test
bunx playwright install chromium
```

**Playwright config** (`playwright.config.ts`):

```typescript
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  outputDir: "./test-results",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ["html", { outputFolder: "playwright-report" }],
    ["json", { outputFile: "test-results/results.json" }],
  ],
  use: {
    baseURL: "http://localhost:3000",
    trace: "on-first-retry",
    screenshot: "only-on-failure",
  },
  projects: [
    {
      name: "Desktop Chrome",
      use: { ...devices["Desktop Chrome"] },
    },
    {
      name: "Mobile Safari",
      use: { ...devices["iPhone 13"] },
    },
    {
      name: "Tablet",
      use: {
        viewport: { width: 768, height: 1024 },
        userAgent: "Mozilla/5.0 (iPad; CPU OS 15_0 like Mac OS X)",
      },
    },
  ],
  webServer: {
    command: "bun run dev",
    port: 3000,
    reuseExistingServer: !process.env.CI,
  },
});
```

**E2E test structure**:

```
e2e/
├── fixtures/           # Shared test data and helpers
│   ├── test-data.ts
│   └── auth.ts        # Login helper
├── flows/             # User flow tests
│   ├── auth.spec.ts
│   ├── onboarding.spec.ts
│   └── [feature].spec.ts
├── visual/            # Visual regression tests
│   ├── screens.spec.ts
│   └── components.spec.ts
└── screenshots/       # Baseline screenshots (committed to git)
    ├── desktop/
    ├── tablet/
    └── mobile/
```

**Map acceptance criteria to E2E tests**:

Each acceptance criterion from the feature spec becomes a test:

```typescript
// e2e/flows/auth.spec.ts
import { test, expect } from "@playwright/test";

// From F-AUTH-001: User Registration
test.describe("User Registration", () => {
  // AC: User can create account with email and password
  test("allows registration with valid email and password", async ({ page }) => {
    await page.goto("/signup");
    await page.fill('[data-testid="email"]', "newuser@example.com");
    await page.fill('[data-testid="password"]', "SecurePass123!");
    await page.click('[data-testid="signup-button"]');
    await expect(page).toHaveURL("/dashboard");
  });

  // AC: Shows validation error for weak password
  test("rejects weak passwords with helpful message", async ({ page }) => {
    await page.goto("/signup");
    await page.fill('[data-testid="email"]', "newuser@example.com");
    await page.fill('[data-testid="password"]', "123");
    await page.click('[data-testid="signup-button"]');
    await expect(page.locator('[data-testid="password-error"]')).toContainText(
      "at least 8 characters",
    );
  });
});
```

### Layer 4: Visual Regression Tests

Compare screenshots of the running application against baseline images (derived from HTML mockups).

**Baseline generation from mockups**:

```typescript
// e2e/visual/generate-baselines.spec.ts
import { test } from "@playwright/test";
import { readdirSync } from "fs";
import { join } from "path";

const mockupsDir = join(__dirname, "../../docs/rest-owl/03-mockups");
const mockups = readdirSync(mockupsDir).filter((f) => f.endsWith(".html"));

for (const mockup of mockups) {
  const name = mockup.replace(".html", "");

  test(`baseline: ${name}`, async ({ page }) => {
    await page.goto(`file://${join(mockupsDir, mockup)}`);
    await page.setViewportSize({ width: 1280, height: 720 });
    await page.screenshot({
      path: `e2e/screenshots/baselines/desktop/${name}.png`,
      fullPage: false,
    });
  });
}
```

**Visual comparison tests**:

```typescript
// e2e/visual/screens.spec.ts
import { test, expect } from "@playwright/test";

const screens = [
  { name: "dashboard-populated", path: "/dashboard", setup: seedDashboardData },
  { name: "dashboard-empty", path: "/dashboard", setup: clearAllData },
  { name: "login-default", path: "/login", setup: null },
  // ... map every mockup to a route + setup function
];

for (const screen of screens) {
  test(`visual: ${screen.name}`, async ({ page }) => {
    if (screen.setup) await screen.setup(page);
    await page.goto(screen.path);
    await page.waitForLoadState("networkidle");

    await expect(page).toHaveScreenshot(`${screen.name}.png`, {
      maxDiffPixelRatio: 0.01, // Allow 1% pixel difference
      threshold: 0.2, // Color difference threshold
      animations: "disabled",
      // Mask dynamic content to prevent flaky tests
      mask: [
        page.locator('[data-testid*="timestamp"]'),
        page.locator('[data-testid*="avatar"]'),
        page.locator('[data-testid*="relative-time"]'),
      ],
    });
  });
}
```

**Important: Preventing flaky visual tests**:

- **Mask dynamic content** — timestamps, avatars, counters, and any content that changes between runs
- **Disable animations** — always use `animations: 'disabled'`
- **Wait for fonts** — use `page.waitForLoadState('networkidle')` before screenshots
- **Generate baselines in CI, not locally** — OS differences (macOS vs Linux) cause font rendering mismatches. Use Playwright's Docker image (`mcr.microsoft.com/playwright`) in CI for consistent results.
- **Start with Chromium only** — add Firefox/WebKit when cross-browser visual bugs actually appear

**Screenshot update workflow**:

```bash
# Update baselines after intentional visual changes
bunx playwright test --update-snapshots
# Review changes in git diff (use a visual diff tool)
git diff --stat e2e/screenshots/
```

## CI Pipeline

### GitHub Actions Workflow

````yaml
name: Test & Visual Regression

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
      - run: bun install
      - run: bun test
      - run: bun test --coverage
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: coverage-report
          path: coverage/

  e2e-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
      - run: bun install
      - run: bunx playwright install --with-deps chromium

      - name: Run E2E tests
        run: bunx playwright test

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: playwright-report
          path: playwright-report/

      - name: Upload screenshots
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-screenshots
          path: test-results/

  visual-regression:
    runs-on: ubuntu-latest
    container:
      image: mcr.microsoft.com/playwright:v1.50.0-noble
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
      - run: bun install

      - name: Run visual regression tests
        run: bunx playwright test e2e/visual/

      - name: Upload visual diffs
        uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: visual-diffs
          path: |
            test-results/**/*-diff.png
            test-results/**/*-actual.png
            test-results/**/*-expected.png

      - name: Upload screenshot baselines
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: screenshot-baselines
          path: e2e/screenshots/

      - name: List visual diffs
        if: failure()
        id: diffs
        run: echo "files=$(find test-results -name '*-diff.png' -exec basename {} \; | tr '\n' ', ')" >> "$GITHUB_OUTPUT"

      - name: Comment visual diff on PR
        if: failure() && github.event_name == 'pull_request'
        uses: peter-evans/create-or-update-comment@v4
        with:
          issue-number: ${{ github.event.pull_request.number }}
          body: |
            ## 🖼️ Visual Regression Detected

            Screenshots have changed. Download the `visual-diffs` artifact to review.

            **Changed screens:** ${{ steps.diffs.outputs.files }}

            If these changes are intentional, update baselines:
            ```bash
            bunx playwright test e2e/visual/ --update-snapshots
            ```
````

### Screenshot Artifact Strategy

CI captures screenshots at three levels:

1. **On failure** — actual vs expected comparison images uploaded as artifacts
2. **On every run** — full set of current screenshots for reference
3. **Baselines in git** — committed baseline screenshots that tests compare against

This means:

- PRs that change the UI must update baseline screenshots
- Visual regressions are caught automatically
- Reviewers can download artifacts to see exactly what changed

## Package.json Scripts

Add these scripts for local development:

```json
{
  "scripts": {
    "test": "bun test",
    "test:coverage": "bun test --coverage",
    "test:e2e": "bunx playwright test",
    "test:e2e:ui": "bunx playwright test --ui",
    "test:visual": "bunx playwright test e2e/visual/",
    "test:visual:update": "bunx playwright test e2e/visual/ --update-snapshots",
    "test:e2e:screenshots": "bunx playwright test e2e/visual/generate-baselines.spec.ts",
    "test:all": "bun test && bunx playwright test"
  }
}
```

## Directory Structure

```
project-root/
├── e2e/
│   ├── fixtures/               # Test helpers and seed data
│   ├── flows/                  # User flow E2E tests
│   ├── visual/                 # Visual regression tests
│   │   ├── screens.spec.ts     # Full-page screenshot comparison
│   │   ├── components.spec.ts  # Component-level comparison
│   │   └── generate-baselines.spec.ts
│   └── screenshots/            # Baseline screenshots (in git)
│       ├── baselines/
│       │   ├── desktop/
│       │   ├── tablet/
│       │   └── mobile/
│       └── .gitkeep
├── test-results/               # Generated (gitignored)
├── playwright-report/          # Generated (gitignored)
├── playwright.config.ts
└── .github/
    └── workflows/
        └── test.yml
```

## Gitignore Additions

```
# Test outputs (regenerated on each run)
test-results/
playwright-report/

# Keep baselines (committed to git)
!e2e/screenshots/
```

## Test Organization Conventions

### Naming

- Unit tests: `*.test.ts` next to source
- E2E flow tests: `e2e/flows/[feature].spec.ts`
- Visual tests: `e2e/visual/[scope].spec.ts`

### Data-testid Attributes

Every interactive or visually significant element gets a `data-testid`:

- Buttons: `data-testid="[action]-button"` (e.g., `submit-button`)
- Inputs: `data-testid="[field]-input"` (e.g., `email-input`)
- Sections: `data-testid="[name]-section"` (e.g., `stats-section`)
- Cards/items: `data-testid="[type]-[id]"` (e.g., `project-123`)

### Test Data

- Use factory functions for test data: `createUser()`, `createProject()`
- Seed data matches the realistic content from mockups
- Each test manages its own state (no shared mutable state between tests)

## Quality Checks

Before completing this phase:

- [ ] Unit test framework configured and passing
- [ ] At least one unit test per utility function
- [ ] Playwright installed and configured for 3 viewports
- [ ] E2E tests exist for every P0 user flow
- [ ] Visual regression baselines generated from mockups
- [ ] Visual comparison tests passing against implementation
- [ ] CI workflow created with all test jobs
- [ ] Screenshot artifacts upload on every CI run
- [ ] PR comment workflow triggers on visual regression failure
- [ ] All tests pass locally before push
- [ ] `.gitignore` correctly handles test output vs baselines
