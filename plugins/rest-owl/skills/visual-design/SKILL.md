---
name: visual-design
description: >
  Generate visual design artifacts for a software project: design system, ASCII wireframes,
  and single-file HTML mockups that render in any browser. Produces testable visual baselines
  for automated screenshot comparison in CI. Used as Phase 3 of the rest-owl workflow.
allowed-tools: Bash, Read, Write, Grep, Glob, Agent, WebSearch, WebFetch, TodoWrite, AskUserQuestion
---

# Visual Design & Mockups

Creates concrete visual representations of every screen in the project — from design tokens to renderable HTML mockups that serve as both design documentation and visual regression baselines.

## When This Skill Activates

- As Phase 3 of the rest-owl workflow
- When a user needs mockups or wireframes for a project
- When setting up visual regression testing baselines

## Input

- Project brief (`docs/rest-owl/00-intake.md`)
- Feature specification (`docs/rest-owl/02-feature-spec.md`), particularly:
  - UI requirements from each feature
  - Screen inventory
  - Interaction flows

## Design Process

### Step 1: Screen Inventory

Extract every screen from the feature spec:

```markdown
## Screen Inventory

| Screen    | Features                    | Priority | States                           |
| --------- | --------------------------- | -------- | -------------------------------- |
| Login     | F-AUTH-001                  | P0       | default, loading, error, success |
| Dashboard | F-DASH-001, F-DASH-002      | P0       | empty, populated, loading        |
| Settings  | F-SET-001 through F-SET-005 | P1       | each tab                         |
```

Identify all **states** for each screen:

- **Default** — normal loaded state
- **Empty** — no data / first-time user
- **Loading** — skeleton/spinner state
- **Error** — something went wrong
- **Success** — action completed
- **Variations** — different content types, permission levels

### Step 2: Design System Definition

Define the visual language before any mockups. Ask the user for preferences:

```markdown
# Design System

## Color Palette

- **Primary**: #[hex] — main actions, links, active states
- **Secondary**: #[hex] — secondary actions, accents
- **Neutral**: #[hex] scale (50-900) — text, borders, backgrounds
- **Success**: #[hex] — confirmations, positive states
- **Warning**: #[hex] — caution states
- **Error**: #[hex] — errors, destructive actions
- **Background**: #[hex] — page background
- **Surface**: #[hex] — card/panel background

## Typography

- **Font family**: [name] (from Google Fonts for mockup portability)
- **Scale**: 12px / 14px / 16px / 18px / 20px / 24px / 32px / 48px
- **Weights**: 400 (regular), 500 (medium), 600 (semibold), 700 (bold)
- **Line heights**: 1.25 (headings), 1.5 (body), 1.75 (relaxed)

## Spacing

- **Base unit**: 4px
- **Scale**: 4 / 8 / 12 / 16 / 20 / 24 / 32 / 48 / 64 / 96

## Border Radius

- **Small**: 4px (buttons, inputs)
- **Medium**: 8px (cards, modals)
- **Large**: 16px (containers)
- **Full**: 9999px (pills, avatars)

## Shadows

- **sm**: 0 1px 2px rgba(0,0,0,0.05)
- **md**: 0 4px 6px rgba(0,0,0,0.07)
- **lg**: 0 10px 15px rgba(0,0,0,0.1)

## Component Library

[List of reusable components: Button, Input, Card, Modal, Dropdown, etc.]
```

Write to `docs/rest-owl/03-design-system.md`.

### Step 3: ASCII Wireframes

Create text-based wireframes for every screen. These serve as quick references and are version-control friendly.

```
┌─────────────────────────────────────────────────────┐
│  ┌──────┐  App Name          🔔  👤  ⚙️            │
│  └──────┘                                           │
├────────────┬────────────────────────────────────────┤
│            │                                        │
│  📁 Home   │  Dashboard                             │
│  📋 Tasks  │  ┌──────────┐ ┌──────────┐ ┌────────┐│
│  👥 Team   │  │ Stat Card│ │ Stat Card│ │  Stat  ││
│  📊 Reports│  │   142    │ │    28    │ │   96%  ││
│  ⚙️ Settings│ └──────────┘ └──────────┘ └────────┘│
│            │                                        │
│            │  Recent Activity                       │
│            │  ┌────────────────────────────────────┐│
│            │  │ ● User did thing — 2m ago          ││
│            │  │ ● Another action — 15m ago         ││
│            │  │ ● Third item — 1h ago              ││
│            │  └────────────────────────────────────┘│
│            │                                        │
└────────────┴────────────────────────────────────────┘
```

Write all wireframes to `docs/rest-owl/03-wireframes.md` with one section per screen.

### Step 4: HTML Mockups

Create **single-file HTML mockups** for every key screen. These are the primary design deliverables — they render in any browser and serve as visual regression baselines.

#### HTML Mockup Requirements

Each mockup file must be:

1. **Self-contained** — single HTML file, no external dependencies except CDN links
2. **Pixel-accurate** — matches the design system exactly
3. **Responsive** — works at desktop (1280px), tablet (768px), and mobile (375px)
4. **State-complete** — each file shows ONE state (create separate files for empty, error, etc.)
5. **Realistic data** — use realistic placeholder content, never "Lorem ipsum"
6. **Screenshot-ready** — at 1280x720 viewport, the mockup looks exactly as intended

#### HTML Mockup Template

The template below uses Tailwind CSS via CDN as a sensible default for rapid mockup creation. If the user expressed different preferences in Phase 0 (e.g., vanilla CSS, Bootstrap, or a specific design framework), adapt the template accordingly. The key requirement is that mockups remain **single-file and self-contained**.

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>[Screen Name] — [Project Name] Mockup</title>
    <!-- Tailwind CSS via CDN (default — adapt to user's preferred CSS framework) -->
    <script src="https://cdn.tailwindcss.com"></script>
    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link href="https://fonts.googleapis.com/css2?family=[Font]&display=swap" rel="stylesheet" />
    <script>
      tailwind.config = {
        theme: {
          extend: {
            colors: {
              primary: {
                /* color scale from design system */
              },
              // ... other design tokens
            },
            fontFamily: {
              sans: ["[Font]", "system-ui", "sans-serif"],
            },
          },
        },
      };
    </script>
    <style>
      /* Any custom styles not covered by Tailwind */
    </style>
  </head>
  <body class="bg-gray-50 font-sans">
    <!-- MOCKUP CONTENT -->
  </body>
</html>
```

#### Mockup File Naming

```
docs/rest-owl/03-mockups/
├── 01-login-default.html
├── 01-login-error.html
├── 02-signup-default.html
├── 03-dashboard-empty.html
├── 03-dashboard-populated.html
├── 03-dashboard-loading.html
├── 04-[screen]-[state].html
└── ...
```

Number prefix matches screen inventory order. States are suffixed.

### Step 5: Interaction Flow Diagrams

Document how users move between screens:

```markdown
## User Flows

### New User Onboarding

Login → Sign Up → Email Verify → Welcome Tour → Dashboard (empty)

### Core Workflow

Dashboard → [Feature Screen] → [Action Modal] → Dashboard (updated)

### Settings

Any Screen → Settings → [Tab] → Save → Previous Screen
```

Use ASCII flow diagrams:

```
[Login] ──→ [Dashboard] ──→ [Project List] ──→ [Project Detail]
   │              │                                    │
   ↓              ↓                                    ↓
[Sign Up]    [Quick Add]                        [Edit Modal]
   │              │                                    │
   ↓              ↓                                    ↓
[Verify]    [Dashboard]                        [Project Detail]
```

### Step 6: Responsive Specifications

For each screen, document responsive behavior:

```markdown
### Dashboard — Responsive Behavior

| Viewport            | Layout                      | Changes                                   |
| ------------------- | --------------------------- | ----------------------------------------- |
| Desktop (≥1024px)   | Sidebar + content           | Full sidebar, 3-column stats              |
| Tablet (768-1023px) | Collapsed sidebar + content | Icon-only sidebar, 2-column stats         |
| Mobile (<768px)     | Bottom nav + content        | No sidebar, stacked stats, hamburger menu |
```

### Step 7: Accessibility Specifications

Document accessibility requirements:

- **Color contrast**: All text meets WCAG AA (4.5:1 for body, 3:1 for large text)
- **Focus indicators**: Visible focus rings on all interactive elements
- **Keyboard navigation**: Tab order for each screen
- **ARIA labels**: For icon-only buttons and complex components
- **Screen reader flow**: Semantic heading structure (h1 → h2 → h3)
- **Reduced motion**: Respect `prefers-reduced-motion`

## Output Files

| File                                | Content                                         |
| ----------------------------------- | ----------------------------------------------- |
| `docs/rest-owl/03-design-system.md` | Complete design token definitions               |
| `docs/rest-owl/03-wireframes.md`    | ASCII wireframes for all screens                |
| `docs/rest-owl/03-mockups/*.html`   | Single-file HTML mockups (one per screen-state) |

## Parallelization

Mockup generation for independent screens can run in parallel via `Agent` tool. Each agent gets:

- The design system document
- The feature spec for its screen
- The HTML template

## Visual Regression Baseline

The HTML mockups serve double duty:

1. **Design documentation** — stakeholders can open them in a browser to review
2. **Visual baselines** — the validation-pipeline skill uses Playwright to screenshot these at standard viewports and compare against the implemented UI

This means mockup accuracy directly affects CI — if the implementation doesn't match the mockup, visual regression tests fail.

## Quality Checks

Before completing this phase:

- [ ] Design system has complete color, typography, and spacing definitions
- [ ] Every screen from the feature spec has a wireframe
- [ ] Every P0 screen has at least a default-state HTML mockup
- [ ] HTML mockups render correctly at 1280x720 viewport
- [ ] Mockups use realistic placeholder data
- [ ] Responsive behavior is documented for all screens
- [ ] Accessibility requirements are specified
- [ ] User has reviewed and approved the visual direction
