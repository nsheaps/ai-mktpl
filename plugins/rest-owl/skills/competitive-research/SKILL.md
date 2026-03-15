---
name: competitive-research
description: >
  Deep competitive analysis for a software project idea. Researches existing products,
  builds feature matrices, identifies UX patterns, and maps the competitive landscape.
  Used as Phase 1 of the rest-owl workflow.
allowed-tools: Bash, Read, Write, Agent, WebSearch, WebFetch, TodoWrite, AskUserQuestion
---

# Competitive Research

Systematic competitive analysis that transforms a project brief into a thorough understanding of the market landscape, user expectations, and opportunities for differentiation.

## When This Skill Activates

- As Phase 1 of the rest-owl workflow
- When a user asks to research competitors for a product idea
- When someone needs a feature comparison matrix for a product category

## Input

A project brief (`docs/rest-owl/00-intake.md`) containing:
- The product idea
- Target users
- Platform and scale
- Key differentiator

## Research Process

### Step 1: Identify the Product Category

Determine the correct product category and adjacent categories. For example:
- "Notion clone" → note-taking, knowledge management, project management, wikis
- "Slack competitor" → team messaging, async communication, collaboration platforms
- "Personal finance tracker" → budgeting apps, expense trackers, financial dashboards

### Step 2: Find Competitors (5-10 products)

Use `WebSearch` to identify both direct and indirect competitors. For each category:

1. **Search queries** (run in parallel via `Agent` tool):
   - `"best <category> apps 2025"`
   - `"<category> software comparison"`
   - `"<category> alternatives to <market leader>"`
   - `"open source <category>"`
   - `"<category> for <target audience>"`

2. **Classify competitors**:
   - **Direct**: Same product category and target audience
   - **Indirect**: Adjacent category or different audience but overlapping features
   - **Open source**: Community-driven alternatives (important for tech research)

### Step 3: Analyze Each Competitor

For each identified competitor, research and document:

#### Product Profile
- **Name and URL**
- **Tagline / value proposition** (from their homepage)
- **Target audience** (who they market to)
- **Pricing model** (free, freemium, subscription, one-time)
- **Platform availability** (web, iOS, Android, desktop, API)

#### Feature Inventory
Use `WebFetch` on competitor marketing pages, feature lists, and documentation to extract:
- Core features (what every user uses)
- Power features (what advanced users rely on)
- Differentiating features (what makes them unique)
- Integration capabilities (what they connect to)

#### UX Patterns
Research their UI/UX approach:
- Navigation patterns (sidebar, top nav, command palette)
- Content organization (pages, boards, lists, timelines)
- Collaboration model (real-time, async, comments, mentions)
- Onboarding flow (how new users get started)
- Mobile experience (responsive, native app, PWA)

#### Technology Stack (when discoverable)
- Frontend framework (check job postings, GitHub, blog posts)
- Backend / API approach
- Database choices
- Notable technical decisions

### Step 4: Build Feature Matrix

Create a comparison table with:
- Rows: Features (grouped by domain)
- Columns: Competitors
- Cells: ✅ (has it), ⚡ (best-in-class), ➖ (basic/limited), ❌ (missing)

```markdown
| Feature | Competitor A | Competitor B | Competitor C | Our Target |
|---------|-------------|-------------|-------------|-----------|
| Rich text editing | ✅ | ⚡ | ➖ | ⚡ |
| Real-time collab | ⚡ | ✅ | ❌ | ✅ |
| API access | ✅ | ✅ | ❌ | ✅ |
| Mobile app | ⚡ | ➖ | ✅ | ➖ |
```

### Step 5: Identify Patterns and Opportunities

Synthesize findings into:

1. **Table stakes features** — What every product in this space must have (P0)
2. **Expected features** — What users will look for but can live without initially (P1)
3. **Differentiating features** — Opportunities where competitors are weak (P2)
4. **Innovative features** — New ideas not yet in the market (P3)

5. **Common UX patterns** — Patterns that users have been trained to expect
6. **Anti-patterns** — Things competitors get wrong that we should avoid
7. **Technology trends** — Modern tech choices being adopted in this space

### Step 6: Recommend Technology Direction

Based on competitor analysis, suggest:
- Which tech stacks are proven in this space
- Which architectural patterns are common (monolith, microservices, serverless)
- Whether real-time capabilities are expected
- What third-party services are commonly used (auth, payments, storage, search)

## Output Format

Write the complete analysis to `docs/rest-owl/01-competitive-research.md`:

```markdown
# Competitive Research: [Project Name]

## Executive Summary
[2-3 paragraph overview of the competitive landscape]

## Product Category
[Primary and adjacent categories]

## Competitor Profiles

### [Competitor 1 Name]
- **URL**: ...
- **Value Proposition**: ...
- **Target Audience**: ...
- **Pricing**: ...
- **Platforms**: ...
- **Key Features**: ...
- **Strengths**: ...
- **Weaknesses**: ...

[Repeat for each competitor]

## Feature Matrix
[Comparison table]

## Feature Priority Map

### P0 — Table Stakes
[Features every product must have]

### P1 — Expected
[Features users will look for]

### P2 — Differentiators
[Opportunities to stand out]

### P3 — Innovative
[New ideas worth exploring]

## UX Patterns
[Common patterns users expect]

## Technology Landscape
[What stacks/architectures competitors use]

## Recommendations
[Specific recommendations for our project]
```

## Parallelization

Launch competitor research agents in parallel — each agent researches one competitor independently. Then compile results in the main thread.

```
Agent 1: Research Competitor A → profile + features
Agent 2: Research Competitor B → profile + features
Agent 3: Research Competitor C → profile + features
...
Main thread: Compile into feature matrix + analysis
```

## Quality Checks

Before completing this phase:
- [ ] At least 5 competitors analyzed
- [ ] Feature matrix has at least 15 features
- [ ] Each competitor has strengths AND weaknesses identified
- [ ] Clear P0/P1/P2/P3 feature priority classification
- [ ] Technology recommendations are specific, not generic
- [ ] All URLs and claims are sourced from web research, not hallucinated
